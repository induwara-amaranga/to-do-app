import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';

import '../helpers/test_data.dart';

/// Re-reads everything from disk through a brand new [ToDoDataBase].
Future<ToDoDataBase> reopen(TestDb env) async {
  // The app stamps the schema version at startup; without it openBoxes()
  // treats the calendar boxes as pre-v3 and deletes them.
  final meta = Hive.box('meta');
  if (meta.get('schemaVersion') == null) {
    await meta.put('schemaVersion', kCurrentSchemaVersion);
  }
  await Hive.close();
  Hive.init(env.dir.path);
  final fresh = ToDoDataBase();
  await fresh.openBoxes();
  fresh.loadData();
  return fresh;
}

void main() {
  late TestDb env;
  late ToDoDataBase db;

  setUp(() async {
    env = await TestDb.open();
    db = env.db;
  });
  tearDown(() async {
    // Migration code fires saves without awaiting them; let them finish.
    await Future.delayed(const Duration(milliseconds: 200));
    await env.dispose();
  });

  group('fresh install', () {
    test('is detected when nothing has been saved', () {
      expect(db.isFreshInstall, isTrue);
    });

    test('createInitialData seeds the default categories', () {
      db.createInitialData();
      expect(db.categories, ['None', 'Work', 'Personal', 'Study', 'Others']);
      expect(db.toDoList, isEmpty);
    });

    test('is no longer fresh once the schema version is stored', () {
      db.runMigrations();
      expect(db.isFreshInstall, isFalse);
    });

    test('is no longer fresh once tasks exist', () async {
      await db.appendTask(makeTask('x'));
      expect(db.isFreshInstall, isFalse);
    });

    test('runMigrations stamps the current schema version', () async {
      db.runMigrations();
      final meta = Hive.box('meta');
      expect(meta.get('schemaVersion'), kCurrentSchemaVersion);
    });
  });

  group('task persistence round-trip', () {
    test('every Task field survives a save and reload', () async {
      final task = Task(
        name: 'Full',
        completed: true,
        note: 'n',
        dueDate: '2025-05-06',
        dueTime: '07:08',
        category: 'Work',
        priority: 'High',
        repeatType: 'weekly',
        reminderAmount: 30,
        reminderType: 'minutes',
        isStarred: true,
        createdAt: '2025-01-01 00:00:00.000Z',
        id: 'abc',
        subtasks: [
          SubTask(
            name: 'sub',
            dueDate: '2025-05-06',
            dueTime: '06:00',
            completed: true,
          ),
          SubTask(name: 'bare'),
        ],
        localCalendarId: 'lc',
        localEventId: 'le',
        remoteEventIds: ['', 'g1', 'o1'],
        source: 'google',
        completedAt: '2025-05-06 07:00:00.000Z',
        notificationIds: [11, 22],
      );
      db.toDoList = [task];
      await db.saveToDoList();

      final back = (await reopen(env)).toDoList.single;
      expect(back.name, 'Full');
      expect(back.completed, isTrue);
      expect(back.note, 'n');
      expect(back.dueDate, '2025-05-06');
      expect(back.dueTime, '07:08');
      expect(back.category, 'Work');
      expect(back.priority, 'High');
      expect(back.repeatType, 'weekly');
      expect(back.reminderAmount, 30);
      expect(back.reminderType, 'minutes');
      expect(back.isStarred, isTrue);
      expect(back.createdAt, '2025-01-01 00:00:00.000Z');
      expect(back.id, 'abc');
      expect(back.subtasks.length, 2);
      expect(back.subtasks.first.name, 'sub');
      expect(back.subtasks.first.dueDate, '2025-05-06');
      expect(back.subtasks.first.dueTime, '06:00');
      expect(back.subtasks.first.completed, isTrue);
      expect(back.subtasks.last.dueDate, isNull);
      expect(back.localCalendarId, 'lc');
      expect(back.localEventId, 'le');
      expect(back.remoteEventIds, ['', 'g1', 'o1']);
      expect(back.source, 'google');
      expect(back.completedAt, '2025-05-06 07:00:00.000Z');
      expect(back.notificationIds, [11, 22]);
    });

    test('null optional fields stay null', () async {
      db.toDoList = [Task(name: 'Bare', id: 'b')];
      await db.saveToDoList();
      final back = (await reopen(env)).toDoList.single;
      expect(back.note, isNull);
      expect(back.dueDate, isNull);
      expect(back.repeatType, isNull);
    });

    test('order is preserved', () async {
      db.toDoList = [makeTask('1'), makeTask('2'), makeTask('3')];
      await db.saveToDoList();
      final back = await reopen(env);
      expect(back.toDoList.map((t) => t.name), ['1', '2', '3']);
    });

    test('calendar events round-trip in all three boxes', () async {
      db.localCalTasks = [makeEvent('L', source: 'local')];
      db.googleCalTasks = [makeEvent('G', remoteEventId: 'g-9')];
      db.outlookCalTasks = [makeEvent('O', source: 'outlook')];
      await db.saveLocalCalTasks();
      await db.saveGoogleCalTasks();
      await db.saveOutlookCalTasks();

      final back = await reopen(env);
      expect(back.localCalTasks.single.name, 'L');
      expect(back.googleCalTasks.single.name, 'G');
      expect(back.googleCalTasks.single.remoteEventId, 'g-9');
      expect(back.outlookCalTasks.single.source, 'outlook');
    });

    test('saveToDoList replaces rather than appends', () async {
      db.toDoList = [makeTask('a'), makeTask('b')];
      await db.saveToDoList();
      db.toDoList = [makeTask('c')];
      await db.saveToDoList();
      expect((await reopen(env)).toDoList.map((t) => t.name), ['c']);
    });
  });

  group('per-record helpers', () {
    test('appendTask adds to memory and disk', () async {
      await db.appendTask(makeTask('one'));
      await db.appendTask(makeTask('two'));
      expect(db.toDoList.length, 2);
      expect((await reopen(env)).toDoList.map((t) => t.name), ['one', 'two']);
    });

    test('saveTaskAt writes only that task', () async {
      await db.appendTask(makeTask('one'));
      await db.appendTask(makeTask('two'));
      db.toDoList[1].completed = true;
      db.toDoList[0].name = 'not saved yet';
      await db.saveTaskAt(1);

      final back = await reopen(env);
      expect(back.toDoList[1].completed, isTrue);
      expect(back.toDoList[0].name, 'one');
    });

    test('saveTaskAt ignores out-of-range indexes', () async {
      await db.appendTask(makeTask('one'));
      await db.saveTaskAt(-1);
      await db.saveTaskAt(5);
      expect((await reopen(env)).toDoList.length, 1);
    });

    test('removeTaskAt removes from memory and disk', () async {
      await db.appendTask(makeTask('a'));
      await db.appendTask(makeTask('b'));
      await db.appendTask(makeTask('c'));
      await db.removeTaskAt(1);
      expect(db.toDoList.map((t) => t.name), ['a', 'c']);
      expect((await reopen(env)).toDoList.map((t) => t.name), ['a', 'c']);
    });

    test('removeTaskAt ignores out-of-range indexes', () async {
      await db.appendTask(makeTask('a'));
      await db.removeTaskAt(3);
      await db.removeTaskAt(-1);
      expect(db.toDoList.length, 1);
    });

    test(
      'a save only ever touches that task, not unsaved neighbours',
      () async {
        await db.appendTask(makeTask('a'));
        await db.appendTask(makeTask('b'));
        db.toDoList.add(makeTask('never saved'));
        db.toDoList[0].name = 'edited';
        await db.saveTaskAt(0);
        final back = (await reopen(env)).toDoList;
        expect(back.map((t) => t.name), ['edited', 'b']);
      },
    );
  });

  group('order and single-record writes', () {
    /// Number of Hive write events produced by [action].
    Future<int> writes(Future<void> Function() action) async {
      final events = <BoxEvent>[];
      final sub = Hive.box<Task>('tasks').watch().listen(events.add);
      await action();
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      return events.length;
    }

    Future<void> seed(List<String> names) async {
      for (final n in names) {
        await db.appendTask(makeTask(n));
      }
    }

    List<String> names(ToDoDataBase d) =>
        d.toDoList.map((t) => t.name).toList();

    test('tasks are stored under their id', () async {
      final t = makeTask('x', id: 'my-id');
      await db.appendTask(t);
      expect(Hive.box<Task>('tasks').keys, ['my-id']);
    });

    test('append, edit and delete are one write each', () async {
      await seed(['a', 'b', 'c']);
      expect(await writes(() => db.appendTask(makeTask('d'))), 1);
      db.toDoList[1].completed = true;
      expect(await writes(() => db.saveTaskAt(1)), 1);
      expect(await writes(() => db.removeTaskAt(2)), 1);
    });

    test('moving a task is one write and survives a restart', () async {
      await seed(['a', 'b', 'c', 'd']);
      expect(await writes(() => db.moveTask(0, 2)), 1);
      expect(names(db), ['b', 'c', 'a', 'd']);
      expect(names(await reopen(env)), ['b', 'c', 'a', 'd']);
    });

    test('moving to either end', () async {
      await seed(['a', 'b', 'c']);
      await db.moveTask(2, 0);
      expect(names(db), ['c', 'a', 'b']);
      await db.moveTask(0, 2);
      expect(names(db), ['a', 'b', 'c']);
      expect(names(await reopen(env)), ['a', 'b', 'c']);
    });

    test('moving leaves every other task order untouched', () async {
      await seed(['a', 'b', 'c', 'd']);
      final before = {for (final t in db.toDoList) t.name: t.order};
      await db.moveTask(3, 1);
      for (final t in db.toDoList) {
        if (t.name != 'd') expect(t.order, before[t.name], reason: t.name);
      }
    });

    test('moving to the same place or out of range does nothing', () async {
      await seed(['a', 'b']);
      expect(await writes(() => db.moveTask(1, 1)), 0);
      expect(await writes(() => db.moveTask(5, 0)), 0);
      expect(await writes(() => db.moveTask(-1, 0)), 0);
      expect(names(db), ['a', 'b']);
    });

    test('undo-delete puts the task back in place with one write', () async {
      await seed(['a', 'b', 'c', 'd']);
      final removed = db.toDoList[1];
      await db.removeTaskAt(1);
      expect(names(db), ['a', 'c', 'd']);
      expect(await writes(() => db.insertTaskAt(1, removed)), 1);
      expect(names(db), ['a', 'b', 'c', 'd']);
      expect(names(await reopen(env)), ['a', 'b', 'c', 'd']);
    });

    test('undo-delete at the ends and past the end', () async {
      await seed(['a', 'b', 'c']);
      final first = db.toDoList.first;
      final last = db.toDoList.last;
      await db.removeTaskAt(0);
      await db.insertTaskAt(0, first);
      await db.removeTaskAt(2);
      await db.insertTaskAt(99, last); // clamped to the end
      expect(names(db), ['a', 'b', 'c']);
      expect(names(await reopen(env)), ['a', 'b', 'c']);
    });

    test('a long run of drags keeps the order correct', () async {
      await seed(['a', 'b', 'c', 'd', 'e']);
      final expected = ['a', 'b', 'c', 'd', 'e'];
      // Repeatedly drop the last item between the first two: the gap halves
      // each time, so this exhausts double precision and must renumber.
      for (var i = 0; i < 80; i++) {
        final moved = expected.removeLast();
        expected.insert(1, moved);
        await db.moveTask(db.toDoList.length - 1, 1);
        expect(names(db), expected, reason: 'drag $i');
      }
      expect(names(await reopen(env)), expected);
    });

    test('orders strictly increase after any sequence of edits', () async {
      await seed(['a', 'b', 'c', 'd', 'e', 'f']);
      await db.moveTask(5, 0);
      await db.moveTask(0, 3);
      final t = db.toDoList[2];
      await db.removeTaskAt(2);
      await db.insertTaskAt(4, t);
      await db.appendTask(makeTask('g'));
      for (var i = 1; i < db.toDoList.length; i++) {
        expect(
          db.toDoList[i].order,
          greaterThan(db.toDoList[i - 1].order),
          reason: 'index $i',
        );
      }
    });

    test('order survives the typed adapter round trip', () async {
      await seed(['a', 'b', 'c']);
      await db.moveTask(2, 0);
      final back = await reopen(env);
      expect(back.toDoList.map((t) => t.order).toList(), [
        for (final t in db.toDoList) t.order,
      ]);
    });

    test('a task saved without a fitting order is slotted in place', () async {
      await seed(['a', 'b', 'c']);
      // Code that adds to the list directly leaves order at its default 0.
      final stray = makeTask('stray');
      db.toDoList.insert(2, stray);
      await db.saveTaskAt(2);
      expect(names(await reopen(env)), ['a', 'b', 'stray', 'c']);
    });

    test('saveTasksFrom writes only the new tail', () async {
      await seed(['a', 'b']);
      final start = db.toDoList.length;
      db.toDoList.add(makeTask('c'));
      db.toDoList.add(makeTask('d'));
      expect(await writes(() => db.saveTasksFrom(start)), 2);
      expect(names(await reopen(env)), ['a', 'b', 'c', 'd']);
    });

    test('saveToDoList renumbers to match the list order', () async {
      await seed(['a', 'b', 'c']);
      db.toDoList = db.toDoList.reversed.toList();
      await db.saveToDoList();
      expect(names(await reopen(env)), ['c', 'b', 'a']);
    });

    test('duplicate and empty ids are repaired on a full save', () async {
      db.toDoList = [
        makeTask('one', id: 'same'),
        makeTask('two', id: 'same'),
        makeTask('three', id: ''),
      ];
      await db.saveToDoList();
      final ids = db.toDoList.map((t) => t.id).toSet();
      expect(ids.length, 3);
      expect(ids, isNot(contains('')));
      expect(names(await reopen(env)), ['one', 'two', 'three']);
    });

    test('a box written by the old int-keyed version is migrated', () async {
      // Old layout: auto-increment int keys, list position = key, no order.
      await Hive.box<Task>('tasks').addAll([
        makeTask('old1', id: 'x1'),
        makeTask('old2', id: ''),
        makeTask('old3', id: 'x1'),
      ]);
      final box = Hive.box<Task>('tasks');
      expect(box.keys.every((k) => k is int), isTrue);

      final back = await reopen(env); // openBoxes() migrates
      expect(names(back), ['old1', 'old2', 'old3']);
      expect(Hive.box<Task>('tasks').keys.every((k) => k is String), isTrue);
      expect(back.toDoList.map((t) => t.id).toSet().length, 3);
    });

    test('migration keeps completed flags and fields', () async {
      await Hive.box<Task>(
        'tasks',
      ).addAll([makeTask('keep', id: 'k', completed: true, priority: 'High')]);
      final t = (await reopen(env)).toDoList.single;
      expect(t.completed, isTrue);
      expect(t.priority, 'High');
    });

    test('opening an already migrated box changes nothing', () async {
      await seed(['a', 'b']);
      final before = db.toDoList.map((t) => t.order).toList();
      final back = await reopen(env);
      expect(back.toDoList.map((t) => t.order).toList(), before);
    });
  });

  group('metadata', () {
    test('categories and hiding categories persist', () async {
      db.categories = ['None', 'Gym'];
      db.hidingCategories = ['Gym'];
      db.saveCategories();
      db.saveHidingCategories();
      final back = await reopen(env);
      expect(back.categories, ['None', 'Gym']);
      expect(back.hidingCategories, ['Gym']);
    });

    test('settings persist', () async {
      db.settings = const AppSettings(
        timeFormat: '24 hour',
        widgetTaskCount: 8,
        morningPlan: true,
      );
      db.saveSettings();
      final back = await reopen(env);
      expect(back.settings.timeFormat, '24 hour');
      expect(back.settings.widgetTaskCount, 8);
      expect(back.settings.morningPlan, isTrue);
    });

    test('syncToCalendars persists', () async {
      db.syncToCalendars = {'local': 'cal-1', 'google': 'none', 'outlook': 'x'};
      db.saveSyncToCalendars();
      final back = await reopen(env);
      expect(back.syncToCalendars['local'], 'cal-1');
      expect(back.syncToCalendars['google'], 'none');
      expect(back.syncToCalendars['outlook'], 'x');
    });

    test('viewOnlyCalendars persist as sets', () async {
      db.viewOnlyCalendars = {
        'local': {'a', 'b'},
        'google': <String>{},
        'outlook': {'z'},
      };
      db.saveViewOnlyCalendars();
      final back = await reopen(env);
      expect(back.viewOnlyCalendars['local'], {'a', 'b'});
      expect(back.viewOnlyCalendars['google'], isEmpty);
      expect(back.viewOnlyCalendars['outlook'], {'z'});
    });

    test('loading with nothing stored keeps the defaults', () {
      db.loadData();
      expect(db.toDoList, isEmpty);
      expect(db.categories, isEmpty);
      expect(db.syncToCalendars['google'], 'none');
      expect(db.viewOnlyCalendars['local'], isEmpty);
      expect(db.settings.completionTone, isTrue);
    });

    test('saveTasksAndCategories writes tasks and categories only', () async {
      db.toDoList = [makeTask('t')];
      db.categories = ['None', 'New'];
      db.hidingCategories = ['New'];
      db.googleCalTasks = [makeEvent('not saved')];
      await db.saveTasksAndCategories();
      final back = await reopen(env);
      expect(back.toDoList.single.name, 't');
      expect(back.categories, ['None', 'New']);
      expect(back.hidingCategories, ['New']);
      expect(back.googleCalTasks, isEmpty);
    });

    test('updateDataBase writes everything', () async {
      db.toDoList = [makeTask('t')];
      db.localCalTasks = [makeEvent('l', source: 'local')];
      db.googleCalTasks = [makeEvent('g')];
      db.outlookCalTasks = [makeEvent('o', source: 'outlook')];
      db.categories = ['None'];
      db.settings = const AppSettings(widgetTaskCount: 2);
      await db.updateDataBase();
      final back = await reopen(env);
      expect(back.toDoList.length, 1);
      expect(back.localCalTasks.length, 1);
      expect(back.googleCalTasks.length, 1);
      expect(back.outlookCalTasks.length, 1);
      expect(back.settings.widgetTaskCount, 2);
    });
  });

  group('clear', () {
    setUp(() async {
      db.toDoList = [makeTask('t')];
      db.localCalTasks = [makeEvent('l', source: 'local')];
      db.googleCalTasks = [makeEvent('g')];
      db.outlookCalTasks = [makeEvent('o', source: 'outlook')];
      await db.updateDataBase();
    });

    test('clearToDoList', () async {
      await db.clearToDoList();
      final back = await reopen(env);
      expect(back.toDoList, isEmpty);
      expect(back.googleCalTasks.length, 1);
    });

    test('clearLocalCalTasks / Google / Outlook are independent', () async {
      await db.clearLocalCalTasks();
      expect(db.localCalTasks, isEmpty);
      expect(db.googleCalTasks.length, 1);
      await db.clearGoogleCalTasks();
      expect(db.googleCalTasks, isEmpty);
      expect(db.outlookCalTasks.length, 1);
      await db.clearOutlookCalTasks();
      expect(db.outlookCalTasks, isEmpty);
      expect(db.toDoList.length, 1);
    });

    test('clearAllCalTasks leaves to-dos untouched', () async {
      await db.clearAllCalTasks();
      final back = await reopen(env);
      expect(back.localCalTasks, isEmpty);
      expect(back.googleCalTasks, isEmpty);
      expect(back.outlookCalTasks, isEmpty);
      expect(back.toDoList.length, 1);
    });
  });

  group('schema handling', () {
    test('boxPath points at the Hive directory', () {
      expect(db.boxPath, startsWith(env.dir.path));
    });

    test('opening with schema < 3 drops the old calendar boxes', () async {
      db.localCalTasks = [makeEvent('stale', source: 'local')];
      await db.saveLocalCalTasks();
      await Hive.box('meta').put('schemaVersion', 2);

      final back = await reopen(env);
      expect(back.localCalTasks, isEmpty);
    });

    test('opening with schema 3 keeps the calendar boxes', () async {
      db.localCalTasks = [makeEvent('kept', source: 'local')];
      await db.saveLocalCalTasks();
      await Hive.box('meta').put('schemaVersion', kCurrentSchemaVersion);

      final back = await reopen(env);
      expect(back.localCalTasks.single.name, 'kept');
    });

    test('openBoxes can be called twice without error', () async {
      await db.openBoxes();
      expect(db.isFreshInstall, isTrue);
    });
  });

  group('legacy "mybox" migration', () {
    Future<void> seedLegacy(Map<String, dynamic> data) async {
      final legacy = await Hive.openBox('mybox');
      for (final e in data.entries) {
        await legacy.put(e.key, e.value);
      }
    }

    test('imports tasks, categories, settings and sync config', () async {
      await seedLegacy({
        'TODOLIST': [
          ['Old task', true, 'note', '2024-01-02', '09:00', 'Work', 'High'],
        ],
        'LOCAL_CAL_TASKS': [
          ['Local ev', false, '', '2024-01-02', '10:00'],
        ],
        'CATEGORIES': ['None', 'Legacy'],
        'SETTINGS': {'widgetTaskCount': 7},
        'SYNC_TO_CALENDARS': {
          'local': 'c1',
          'google': 'none',
          'outlook': 'none',
        },
        'VIEW_ONLY_CALENDARS': {
          'local': ['x'],
          'google': [],
          'outlook': [],
        },
      });

      db.runMigrations();

      expect(db.toDoList.single.name, 'Old task');
      expect(db.toDoList.single.completed, isTrue);
      expect(db.toDoList.single.category, 'Work');
      expect(db.localCalTasks.single.name, 'Local ev');
      expect(db.categories, ['None', 'Legacy']);
      expect(db.settings.widgetTaskCount, 7);
      expect(db.syncToCalendars['local'], 'c1');
      expect(db.viewOnlyCalendars['local'], {'x'});
      expect(Hive.box('meta').get('schemaVersion'), kCurrentSchemaVersion);
    });

    test('empty legacy box migrates nothing', () async {
      await Hive.openBox('mybox');
      db.runMigrations();
      expect(db.toDoList, isEmpty);
      expect(Hive.box('meta').get('schemaVersion'), kCurrentSchemaVersion);
    });

    test('is skipped when the schema is already current', () async {
      await seedLegacy({
        'TODOLIST': [
          ['Should not import'],
        ],
      });
      await Hive.box('meta').put('schemaVersion', kCurrentSchemaVersion);
      db.runMigrations();
      expect(db.toDoList, isEmpty);
    });

    test('works when mybox was never opened', () {
      expect(db.runMigrations, returnsNormally);
    });
  });

  group('dataRevision', () {
    Future<void> expectBumps(
      String what,
      Future<void> Function() action,
    ) async {
      final before = db.dataRevision;
      await action();
      expect(db.dataRevision, greaterThan(before), reason: what);
    }

    test('every write to the task box bumps it', () async {
      await expectBumps('appendTask', () => db.appendTask(makeTask('a')));
      await db.appendTask(makeTask('b'));
      await db.appendTask(makeTask('c'));
      await expectBumps('saveTaskAt', () => db.saveTaskAt(0));
      await expectBumps('moveTask', () => db.moveTask(0, 2));
      await expectBumps('insertTaskAt', () async {
        final t = db.toDoList.first;
        await db.removeTaskAt(0);
        await db.insertTaskAt(0, t);
      });
      await expectBumps('removeTaskAt', () => db.removeTaskAt(0));
      await expectBumps('saveToDoList', db.saveToDoList);
      await expectBumps(
        'removeTasks',
        () => db.removeTasks([db.toDoList.first]),
      );
      await expectBumps('saveTasksAt', () => db.saveTasksAt([0]));
      db.toDoList.add(makeTask('tail'));
      await expectBumps(
        'saveTasksFrom',
        () => db.saveTasksFrom(db.toDoList.length - 1),
      );
      await expectBumps('clearToDoList', db.clearToDoList);
    });

    test('every write to a calendar box bumps it', () async {
      await expectBumps('saveLocalCalTasks', db.saveLocalCalTasks);
      await expectBumps('saveGoogleCalTasks', db.saveGoogleCalTasks);
      await expectBumps('saveOutlookCalTasks', db.saveOutlookCalTasks);
      await expectBumps('clearLocalCalTasks', db.clearLocalCalTasks);
      await expectBumps('clearGoogleCalTasks', db.clearGoogleCalTasks);
      await expectBumps('clearOutlookCalTasks', db.clearOutlookCalTasks);
    });

    test('reloading from disk bumps it', () {
      final before = db.dataRevision;
      db.loadData();
      expect(db.dataRevision, greaterThan(before));
    });

    test('calls that change nothing leave it alone', () async {
      await db.appendTask(makeTask('a'));
      final before = db.dataRevision;
      await db.saveTaskAt(99);
      await db.removeTaskAt(99);
      await db.moveTask(0, 0);
      await db.removeTasks([]);
      await db.saveTasksFrom(5);
      await db.saveTasksAt([42]);
      expect(db.dataRevision, before);
    });

    test('settings and metadata saves do not count as data changes', () {
      final before = db.dataRevision;
      db.saveSettings();
      db.saveCategories();
      db.saveSyncToCalendars();
      expect(db.dataRevision, before);
    });
  });

  group('saveTasksAt', () {
    test('writes several edited tasks in one batch', () async {
      for (final n in ['a', 'b', 'c', 'd']) {
        await db.appendTask(makeTask(n));
      }
      db.toDoList[0].name = 'A!';
      db.toDoList[2].name = 'C!';
      db.toDoList[3].name = 'unsaved';
      await db.saveTasksAt([0, 2]);
      final back = (await reopen(env)).toDoList.map((t) => t.name).toList();
      expect(back, ['A!', 'b', 'C!', 'd']);
    });

    test('ignores out-of-range and duplicate indexes', () async {
      await db.appendTask(makeTask('a'));
      db.toDoList[0].name = 'edited';
      await db.saveTasksAt([-1, 0, 0, 7]);
      expect((await reopen(env)).toDoList.single.name, 'edited');
    });
  });

  group('legacy box is opened only when it is needed', () {
    Future<void> writeLegacyBox() async {
      final legacy = await Hive.openBox('mybox');
      await legacy.put('TODOLIST', [
        ['Old task', false, '', '2024-01-02', '09:00'],
      ]);
      await legacy.put('CATEGORIES', ['None', 'Legacy']);
      await Hive.close();
    }

    Future<ToDoDataBase> restart() async {
      Hive.init(env.dir.path);
      final fresh = ToDoDataBase();
      await fresh.openBoxes();
      return fresh;
    }

    test('a plain launch never creates or opens it', () async {
      await Hive.close();
      final fresh = await restart();
      expect(Hive.isBoxOpen('mybox'), isFalse);
      expect(
        await Hive.boxExists('mybox'),
        isFalse,
        reason: 'not even created',
      );
      expect(fresh.isFreshInstall, isTrue);
    });

    test('an old install with the box on disk still migrates', () async {
      await Hive.close();
      Hive.init(env.dir.path);
      await writeLegacyBox();

      final fresh = await restart();
      expect(Hive.isBoxOpen('mybox'), isTrue);
      fresh.runMigrations();
      expect(fresh.toDoList.single.name, 'Old task');
      expect(fresh.categories, ['None', 'Legacy']);
    });

    test('once migrated (schema current) the box is left closed', () async {
      await Hive.close();
      Hive.init(env.dir.path);
      await writeLegacyBox();
      var fresh = await restart();
      fresh.runMigrations();
      // The migration saves without awaiting; let those writes finish.
      await Future.delayed(const Duration(milliseconds: 300));
      await Hive.close();

      fresh = await restart();
      expect(Hive.isBoxOpen('mybox'), isFalse);
    });

    test('all other boxes are open after startup', () async {
      await Hive.close();
      await restart();
      for (final name in [
        'meta',
        'tasks',
        'localCalTasks',
        'googleCalTasks',
        'outlookCalTasks',
        'fileMetaBox',
      ]) {
        expect(Hive.isBoxOpen(name), isTrue, reason: name);
      }
    });
  });

  test('test directory is cleaned up', () async {
    final dir = env.dir;
    await env.dispose();
    expect(await dir.exists(), isFalse);
    env = await TestDb.open(); // keep tearDown happy
    db = env.db;
    expect(Directory(env.dir.path).existsSync(), isTrue);
  });

  test('CalendarEvent type is registered with Hive', () {
    expect(Hive.isAdapterRegistered(2), isTrue);
    expect(CalendarEvent(name: 'x', id: '1').name, 'x');
  });
}
