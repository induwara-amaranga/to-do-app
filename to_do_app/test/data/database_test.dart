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

    test('helpers recover when memory and box drift apart', () async {
      await db.appendTask(makeTask('a'));
      await db.appendTask(makeTask('b'));
      // Mutate memory behind the helpers' back.
      db.toDoList.add(makeTask('sneaky'));
      db.toDoList[0].name = 'edited';
      await db.saveTaskAt(0); // lengths differ -> full rewrite
      expect((await reopen(env)).toDoList.map((t) => t.name), [
        'edited',
        'b',
        'sneaky',
      ]);
    });

    test('appendTask falls back to a full rewrite when misaligned', () async {
      await db.appendTask(makeTask('a'));
      db.toDoList.add(makeTask('ghost')); // memory has one extra
      await db.appendTask(makeTask('b'));
      expect((await reopen(env)).toDoList.map((t) => t.name), [
        'a',
        'ghost',
        'b',
      ]);
    });

    test('removeTaskAt falls back to a full rewrite when misaligned', () async {
      await db.appendTask(makeTask('a'));
      await db.appendTask(makeTask('b'));
      db.toDoList.add(makeTask('ghost'));
      await db.removeTaskAt(0);
      expect((await reopen(env)).toDoList.map((t) => t.name), ['b', 'ghost']);
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
        'SYNC_TO_CALENDARS': {'local': 'c1', 'google': 'none', 'outlook': 'none'},
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
