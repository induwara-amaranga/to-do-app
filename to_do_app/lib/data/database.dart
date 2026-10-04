import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';

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

    await Hive.openBox<Task>(_boxTasks);
    await Hive.openBox<CalendarEvent>(_boxLocalCal);
    await Hive.openBox<CalendarEvent>(_boxGoogleCal);
    await Hive.openBox<CalendarEvent>(_boxOutlookCal);
    await Hive.openBox('fileMetaBox');
  }

  void createInitialData() {
    toDoList = [];
    localCalTasks = [];
    googleCalTasks = [];
    outlookCalTasks = [];
    categories = ['None', 'Work', 'Personal', 'Study', 'Others'];
  }

  // ─── Save ───────────────────────────────────────────────────────────────

  Future<void> _replaceTaskBox(Box<Task> box, List<Task> rows) async {
    await box.clear();
    await box.addAll(rows);
  }

  Future<void> _replaceCalBox(
    Box<CalendarEvent> box,
    List<CalendarEvent> rows,
  ) async {
    await box.clear();
    await box.addAll(rows);
  }

  Future<void> saveToDoList() => _replaceTaskBox(_tasksBox, toDoList);

  // ─── Per-record task saves ──────────────────────────────────────────────
  //
  // [toDoList] is loaded as `box.values.toList()`, so list index i lines up
  // with box index i as long as every add/remove goes through the helpers
  // below. That lets a single-task edit write one record instead of clearing
  // and re-adding the whole box. Each helper falls back to a full rewrite if
  // the two ever drift out of alignment, so a missed call path degrades to
  // the old behaviour rather than corrupting the box.

  /// Persists just `toDoList[index]` — use for edits that don't change the
  /// list's length or order (completion toggle, field edit, id backfill).
  Future<void> saveTaskAt(int index) async {
    if (index < 0 || index >= toDoList.length) return;
    final box = _tasksBox;
    if (box.length != toDoList.length) return saveToDoList();
    await box.putAt(index, toDoList[index]);
  }

  /// Appends [task] to both the in-memory list and the box.
  Future<void> appendTask(Task task) async {
    toDoList.add(task);
    final box = _tasksBox;
    if (box.length != toDoList.length - 1) return saveToDoList();
    await box.add(task);
  }

  /// Removes the task at [index] from both the in-memory list and the box.
  Future<void> removeTaskAt(int index) async {
    if (index < 0 || index >= toDoList.length) return;
    final box = _tasksBox;
    final aligned = box.length == toDoList.length;
    toDoList.removeAt(index);
    if (!aligned) return saveToDoList();
    await box.deleteAt(index);
  }

  /// Saves the task box plus the category metadata, leaving the three
  /// calendar boxes untouched. For mutations that only concern to-dos.
  Future<void> saveTasksAndCategories() async {
    await saveToDoList();
    saveCategories();
    saveHidingCategories();
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
    toDoList = [];
    await _tasksBox.clear();
  }

  Future<void> clearLocalCalTasks() async {
    localCalTasks = [];
    await _localCalBox.clear();
  }

  Future<void> clearGoogleCalTasks() async {
    googleCalTasks = [];
    await _googleCalBox.clear();
  }

  Future<void> clearOutlookCalTasks() async {
    outlookCalTasks = [];
    await _outlookCalBox.clear();
  }

  Future<void> clearAllCalTasks() async {
    await clearLocalCalTasks();
    await clearGoogleCalTasks();
    await clearOutlookCalTasks();
  }

  // ─── Load ───────────────────────────────────────────────────────────────

  List<Task> _readTaskBox(Box<Task> box) => box.values.toList();

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
