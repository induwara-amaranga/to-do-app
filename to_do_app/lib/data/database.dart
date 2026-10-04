import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';
import 'package:uuid/uuid.dart';

const int kCurrentSchemaVersion = 3;

/// Typed persistence layer.
/// - On disk:
///     • [Task] (typeId 0)            in box `tasks`
///     • [CalendarEvent] (typeId 2)   in boxes `localCalTasks`, `googleCalTasks`, `outlookCalTasks`
///     • [SubTask] (typeId 1)         embedded inside Task / CalendarEvent
/// - In memory: kept as `List<Task>` / `List<CalendarEvent>` directly — the
///   same objects Hive stores, no positional-list conversion at either
///   boundary.
///
/// Calendar events are intentionally a *separate* model from Task because
/// their positional schema differs (single-String eventId at index 16 vs.
/// list-of-IDs for tasks). Conflating them caused round-trip data loss in
/// schema v2.
class ToDoDataBase {
  static const _boxTasks = 'tasks';
  static const _boxLocalCal = 'localCalTasks';
  static const _boxGoogleCal = 'googleCalTasks';
  static const _boxOutlookCal = 'outlookCalTasks';
  static const _boxMeta = 'meta';
  static const _boxLegacy = 'mybox';

  static const _settingsKey = 'settings';

  List<Task> toDoList = [];
  List<CalendarEvent> localCalTasks = [];
  List<CalendarEvent> googleCalTasks = [];
  List<CalendarEvent> outlookCalTasks = [];
  List<String> categories = [];
  List<String> hidingCategories = [];

  Map<String, Set<String>> viewOnlyCalendars = {
    'local': <String>{},
    'google': <String>{},
    'outlook': <String>{},
  };

  Map<String, dynamic> syncToCalendars = {
    'local': 'none',
    'google': 'none',
    'outlook': 'none',
  };

  AppSettings settings = const AppSettings();

  /// Bumped by every write to the task or calendar boxes. Screens and caches
  /// compare it with the value they last saw to know their data went stale
  /// (e.g. a page left on the back stack while another page edited tasks).
  int dataRevision = 0;

  Box<Task> get _tasksBox => Hive.box<Task>(_boxTasks);
  Box<CalendarEvent> get _localCalBox => Hive.box<CalendarEvent>(_boxLocalCal);
  Box<CalendarEvent> get _googleCalBox =>
      Hive.box<CalendarEvent>(_boxGoogleCal);
  Box<CalendarEvent> get _outlookCalBox =>
      Hive.box<CalendarEvent>(_boxOutlookCal);
  Box get _metaBox => Hive.box(_boxMeta);

  String get boxPath => _metaBox.path ?? '';

  bool get isFreshInstall =>
      _metaBox.get('schemaVersion') == null && _tasksBox.isEmpty;

  Future<void> openBoxes() async {
    // Register all adapters first so any subsequent openBox call can decode.
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SubTaskAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CalendarEventAdapter());
    }

    // Open meta first so we can read schemaVersion before opening typed boxes.
    await Hive.openBox(_boxMeta);

    // Pre-flight: schemas <3 stored cal tasks as Task (typeId 0). We've moved
    // them to CalendarEvent (typeId 2), so the on-disk types are incompatible.
    // Delete the old boxes so the next openBox creates them fresh.
    // Data is recoverable from the legacy `mybox` migration (if present) or
    // by re-running calendar sync.
    final stored = (_metaBox.get('schemaVersion') as int?) ?? 1;
    if (stored < 3) {
      await Hive.deleteBoxFromDisk(_boxLocalCal);
      await Hive.deleteBoxFromDisk(_boxGoogleCal);
      await Hive.deleteBoxFromDisk(_boxOutlookCal);
    }

    // The pre-typed-model box is only needed for the one-time migration, so
    // don't open (or create) it on every launch.
    final needsLegacy =
        stored < 2 &&
        !Hive.isBoxOpen(_boxLegacy) &&
        await Hive.boxExists(_boxLegacy);

    await Future.wait([
      Hive.openBox<Task>(_boxTasks),
      Hive.openBox<CalendarEvent>(_boxLocalCal),
      Hive.openBox<CalendarEvent>(_boxGoogleCal),
      Hive.openBox<CalendarEvent>(_boxOutlookCal),
      Hive.openBox('fileMetaBox'),
      if (needsLegacy) Hive.openBox(_boxLegacy),
    ]);
    await _migrateTaskKeys();
  }

  void createInitialData() {
    toDoList = [];
    localCalTasks = [];
    googleCalTasks = [];
    outlookCalTasks = [];
    categories = ['None', 'Work', 'Personal', 'Study', 'Others'];
  }

  // ─── Save ───────────────────────────────────────────────────────────────

  // ─── Task storage ───────────────────────────────────────────────────────
  //
  // Tasks are stored under their own `id` and each carries an `order` number;
  // [toDoList] is the box sorted by `order`. Nothing depends on a task's
  // position in the box, so every edit below is a single-record write:
  //   * edit / toggle  -> put(id)
  //   * append         -> put(id) with order = last + 1
  //   * delete         -> delete(id)
  //   * undo-delete / drag-reorder -> put(id) with an order halfway between
  //     its new neighbours (fractional, so there is always room)
  // Only when a gap is exhausted (or orders were left inconsistent by code
  // that edits [toDoList] directly) does a write fall back to renumbering the
  // whole box, which is also what [saveToDoList] does.

  static const _uuid = Uuid();

  /// Gives every task a unique, non-empty id and `order = position`.
  void _normalizeTasks(List<Task> rows) {
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final t = rows[i];
      if (t.id.isEmpty || !seen.add(t.id)) {
        t.id = _uuid.v4();
        seen.add(t.id);
      }
      t.order = i.toDouble();
    }
  }

  Future<void> _replaceTaskBox(Box<Task> box, List<Task> rows) async {
    dataRevision++;
    _normalizeTasks(rows);
    await box.clear();
    await box.putAll({for (final t in rows) t.id: t});
  }

  /// Early versions stored tasks under auto-increment int keys, where list
  /// position was the key. Re-keys them by id once, keeping their order.
  Future<void> _migrateTaskKeys() async {
    final box = _tasksBox;
    if (!box.keys.any((k) => k is! String)) return;
    await _replaceTaskBox(box, box.values.toList());
  }

  /// True if `toDoList[index].order` already sits strictly between its
  /// neighbours' orders.
  bool _orderFits(int index) {
    final o = toDoList[index].order;
    if (index > 0 && o <= toDoList[index - 1].order) return false;
    if (index < toDoList.length - 1 && o >= toDoList[index + 1].order) {
      return false;
    }
    return true;
  }

  /// Sets `toDoList[index].order` to fall between its neighbours. Returns
  /// false when there is no room (the caller then renumbers everything).
  bool _assignOrderAt(int index) {
    final prev = index > 0 ? toDoList[index - 1].order : null;
    final next = index < toDoList.length - 1 ? toDoList[index + 1].order : null;
    final double o;
    if (prev == null && next == null) {
      o = 0;
    } else if (prev == null) {
      o = next! - 1;
    } else if (next == null) {
      o = prev + 1;
    } else {
      if (prev >= next) return false;
      o = (prev + next) / 2;
      if (!(o > prev && o < next)) return false;
    }
    toDoList[index].order = o;
    return true;
  }

  /// Writes `toDoList[index]` alone, first giving it an order that fits (or
  /// renumbering the box if none does).
  Future<void> _putTaskAt(int index) async {
    dataRevision++;
    final task = toDoList[index];
    if (task.id.isEmpty) task.id = _uuid.v4();
    if (!_orderFits(index) && !_assignOrderAt(index)) return saveToDoList();
    await _tasksBox.put(task.id, task);
  }

  /// Replaces the whole task box with [toDoList], in list order. Use for bulk
  /// changes; single edits have the cheaper helpers below.
  Future<void> saveToDoList() => _replaceTaskBox(_tasksBox, toDoList);

  /// Persists just `toDoList[index]` — use for edits that don't change the
  /// list's length or order (completion toggle, field edit, id backfill).
  Future<void> saveTaskAt(int index) async {
    if (index < 0 || index >= toDoList.length) return;
    await _putTaskAt(index);
  }

  /// Appends [task] to both the in-memory list and the box.
  Future<void> appendTask(Task task) async {
    toDoList.add(task);
    await _putTaskAt(toDoList.length - 1);
  }

  /// Writes the tasks at [indexes] in one batch — for code that edited
  /// several existing tasks in place (calendar imports).
  Future<void> saveTasksAt(Iterable<int> indexes) async {
    final rows = <String, Task>{};
    for (final i in indexes) {
      if (i < 0 || i >= toDoList.length) continue;
      final t = toDoList[i];
      if (t.id.isEmpty) t.id = _uuid.v4();
      if (!_orderFits(i) && !_assignOrderAt(i)) return saveToDoList();
      rows[t.id] = t;
    }
    if (rows.isEmpty) return;
    dataRevision++;
    await _tasksBox.putAll(rows);
  }

  /// Writes the tasks from index [start] to the end of [toDoList] — for code
  /// that has just appended several to the list directly.
  Future<void> saveTasksFrom(int start) async {
    if (start >= toDoList.length) return;
    dataRevision++;
    final fresh = <String, Task>{};
    for (var i = start; i < toDoList.length; i++) {
      final t = toDoList[i];
      if (t.id.isEmpty) t.id = _uuid.v4();
      // The tail is the end of the list, so each task simply follows the one
      // before it.
      t.order = i > 0 ? toDoList[i - 1].order + 1 : 0;
      fresh[t.id] = t;
    }
    await _tasksBox.putAll(fresh);
  }

  /// Removes the task at [index] from both the in-memory list and the box.
  Future<void> removeTaskAt(int index) async {
    if (index < 0 || index >= toDoList.length) return;
    dataRevision++;
    final task = toDoList.removeAt(index);
    await _tasksBox.delete(task.id);
  }

  /// Removes every task in [doomed] from the list and the box in one batch.
  Future<void> removeTasks(Iterable<Task> doomed) async {
    final set = Set<Task>.identity()..addAll(doomed);
    if (set.isEmpty) return;
    dataRevision++;
    toDoList.removeWhere(set.contains);
    await _tasksBox.deleteAll(set.map((t) => t.id));
  }

  /// Puts [task] back at [index] (clamped), e.g. when a delete is undone.
  Future<void> insertTaskAt(int index, Task task) async {
    final at = index.clamp(0, toDoList.length);
    toDoList.insert(at, task);
    await _putTaskAt(at);
  }

  /// Moves the task at [from] so it ends up at index [to].
  Future<void> moveTask(int from, int to) async {
    if (from < 0 || from >= toDoList.length || from == to) return;
    final task = toDoList.removeAt(from);
    final at = to.clamp(0, toDoList.length);
    toDoList.insert(at, task);
    await _putTaskAt(at);
  }

  /// Saves the task box plus the category metadata, leaving the three
  /// calendar boxes untouched. For mutations that only concern to-dos.
  Future<void> saveTasksAndCategories() async {
    await saveToDoList();
    saveCategories();
    saveHidingCategories();
  }

  Future<void> _replaceCalBox(
    Box<CalendarEvent> box,
    List<CalendarEvent> rows,
  ) async {
    dataRevision++;
    await box.clear();
    await box.addAll(rows);
  }

  Future<void> saveLocalCalTasks() {
    return _replaceCalBox(_localCalBox, localCalTasks);
  }

  Future<void> saveGoogleCalTasks() =>
      _replaceCalBox(_googleCalBox, googleCalTasks);
  Future<void> saveOutlookCalTasks() =>
      _replaceCalBox(_outlookCalBox, outlookCalTasks);

  void saveCategories() => _metaBox.put('categories', categories);

  void saveHidingCategories() =>
      _metaBox.put('hidingCategories', hidingCategories);
  void saveSettings() => _metaBox.put('settings', settings.toMap());
  void saveSyncToCalendars() =>
      _metaBox.put('syncToCalendars', syncToCalendars);

  void saveViewOnlyCalendars() {
    _metaBox.put('viewOnlyCalendars', {
      'local': viewOnlyCalendars['local']!.toList(),
      'google': viewOnlyCalendars['google']!.toList(),
      'outlook': viewOnlyCalendars['outlook']!.toList(),
    });
  }

  // ─── Clear ──────────────────────────────────────────────────────────────

  Future<void> clearToDoList() async {
    dataRevision++;
    toDoList = [];
    await _tasksBox.clear();
  }

  Future<void> clearLocalCalTasks() async {
    dataRevision++;
    localCalTasks = [];
    await _localCalBox.clear();
  }

  Future<void> clearGoogleCalTasks() async {
    dataRevision++;
    googleCalTasks = [];
    await _googleCalBox.clear();
  }

  Future<void> clearOutlookCalTasks() async {
    dataRevision++;
    outlookCalTasks = [];
    await _outlookCalBox.clear();
  }

  Future<void> clearAllCalTasks() async {
    await clearLocalCalTasks();
    await clearGoogleCalTasks();
    await clearOutlookCalTasks();
  }

  // ─── Load ───────────────────────────────────────────────────────────────

  /// The box contents in the user's order (stable for equal `order`s).
  List<Task> _readTaskBox(Box<Task> box) {
    final keyed = [for (final t in box.values.indexed) (task: t.$2, pos: t.$1)];
    keyed.sort((a, b) {
      final c = a.task.order.compareTo(b.task.order);
      return c != 0 ? c : a.pos.compareTo(b.pos);
    });
    return [for (final e in keyed) e.task];
  }

  List<CalendarEvent> _readCalBox(Box<CalendarEvent> box) =>
      box.values.toList();

  void loadToDoList() => toDoList = _readTaskBox(_tasksBox);
  void loadLocalCalTasks() {
    localCalTasks = _readCalBox(_localCalBox);
  }

  void loadGoogleCalTasks() => googleCalTasks = _readCalBox(_googleCalBox);
  void loadOutlookCalTasks() => outlookCalTasks = _readCalBox(_outlookCalBox);

  void loadCategories() {
    final data = _metaBox.get('categories');
    if (data is List) categories = data.cast<String>();
  }

  void loadHidingCategories() {
    final data = _metaBox.get('hidingCategories');
    if (data is List) hidingCategories = data.cast<String>();
  }

  void loadSettings() {
    final data = _metaBox.get('settings');
    if (data is Map) {
      settings = AppSettings.fromMap(data);
    }
  }

  void loadSyncToCalendars() {
    final data = _metaBox.get('syncToCalendars');
    if (data is Map) {
      syncToCalendars = Map<String, dynamic>.from(data.cast<String, dynamic>());
    }
  }

  void loadViewOnlyCalendars() {
    final data = _metaBox.get('viewOnlyCalendars');
    if (data is Map) {
      viewOnlyCalendars = {
        'local': ((data['local'] as List?) ?? const []).cast<String>().toSet(),
        'google':
            ((data['google'] as List?) ?? const []).cast<String>().toSet(),
        'outlook':
            ((data['outlook'] as List?) ?? const []).cast<String>().toSet(),
      };
    }
  }

  void loadData() {
    dataRevision++;
    loadToDoList();
    loadLocalCalTasks();
    loadGoogleCalTasks();
    loadOutlookCalTasks();
    loadCategories();
    loadHidingCategories();
    loadSettings();
    loadSyncToCalendars();
    loadViewOnlyCalendars();
  }

  Future<void> updateDataBase() async {
    await saveToDoList();
    await saveLocalCalTasks();
    await saveGoogleCalTasks();
    await saveOutlookCalTasks();
    saveCategories();
    saveHidingCategories();
    saveSettings();
    saveSyncToCalendars();
    saveViewOnlyCalendars();
  }

  // ─── Migration ──────────────────────────────────────────────────────────

  void runMigrations() {
    final stored = (_metaBox.get('schemaVersion') as int?) ?? 1;
    if (stored < kCurrentSchemaVersion) {
      if (stored < 2) _migrateLegacyMyBox();
      // v2 → v3 work was done in openBoxes() (cal boxes were deleted there).
      _metaBox.put('schemaVersion', kCurrentSchemaVersion);
    }
  }

  void _migrateLegacyMyBox() {
    if (!Hive.isBoxOpen('mybox')) return;
    final legacy = Hive.box('mybox');
    if (legacy.isEmpty) return;

    List<List<dynamic>> readRows(String key) {
      final raw = legacy.get(key);
      if (raw is! List) return [];
      return raw.whereType<List>().map((e) => List<dynamic>.from(e)).toList();
    }

    final legacyToDo = readRows('TODOLIST');
    final legacyLocal = readRows('LOCAL_CAL_TASKS');
    final legacyGoogle = readRows('GOOGLE_CAL_TASKS');
    final legacyOutlook = readRows('OUTLOOK_CAL_TASKS');

    if (legacyToDo.isNotEmpty) {
      toDoList = legacyToDo.map(Task.fromList).toList();
      saveToDoList();
    }
    if (legacyLocal.isNotEmpty) {
      localCalTasks = legacyLocal.map(CalendarEvent.fromList).toList();
      saveLocalCalTasks();
    }
    if (legacyGoogle.isNotEmpty) {
      googleCalTasks = legacyGoogle.map(CalendarEvent.fromList).toList();
      saveGoogleCalTasks();
    }
    if (legacyOutlook.isNotEmpty) {
      outlookCalTasks = legacyOutlook.map(CalendarEvent.fromList).toList();
      saveOutlookCalTasks();
    }

    final cats = legacy.get('CATEGORIES');
    if (cats is List) {
      categories = cats.cast<String>();
      saveCategories();
    }

    final s = legacy.get('SETTINGS');
    if (s is Map) {
      settings = AppSettings.fromMap(s);
      saveSettings();
    }

    final sync = legacy.get('SYNC_TO_CALENDARS');
    if (sync is Map) {
      syncToCalendars = Map<String, dynamic>.from(sync.cast<String, dynamic>());
      saveSyncToCalendars();
    }

    final view = legacy.get('VIEW_ONLY_CALENDARS');
    if (view is Map) {
      viewOnlyCalendars = {
        'local': ((view['local'] as List?) ?? const []).cast<String>().toSet(),
        'google':
            ((view['google'] as List?) ?? const []).cast<String>().toSet(),
        'outlook':
            ((view['outlook'] as List?) ?? const []).cast<String>().toSet(),
      };
      saveViewOnlyCalendars();
    }

    legacy.clear();
  }
}
