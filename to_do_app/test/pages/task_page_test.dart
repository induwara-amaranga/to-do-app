import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/pages/task_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/app_startup.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/providers/data_provider.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/themes/light_mode.dart';

import '../helpers/test_data.dart';

/// Renders the real [TaskPage] against an in-memory [ToDoDataBase].
/// No Hive box is opened, so these tests only exercise display and
/// navigation, not the save paths (those are covered in database_test.dart).
Future<SearchingProvider> pumpTaskPage(
  WidgetTester t,
  ToDoDataBase db, {
  GroupingMode grouping = GroupingMode.Default,
  bool settle = true,
  void Function(CalendarSyncProvider)? onSync,
}) async {
  final search = SearchingProvider();
  final sync = CalendarSyncProvider();
  if (onSync != null) sync.addListener(() => onSync(sync));
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GroupingProvider()..setMode(grouping),
        ),
        ChangeNotifierProvider(create: (_) => SortingProvider()),
        ChangeNotifierProvider.value(value: search),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider(create: (_) => ViewProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider(db)),
      ],
      child: MaterialApp(
        theme: lightMode,
        home: TaskPage(db: db, updateMissedTasks: false, filePath: null),
      ),
    ),
  );
  if (settle) await t.pumpAndSettle();
  return search;
}

ToDoDataBase newDb() {
  final db = ToDoDataBase();
  db.createInitialData();
  return db;
}

void main() {
  setUpAll(initTestTimeZone);
  fineGrainedTests();
  pastTaskCleanupTests();
  cacheAndSyncTests();

  testWidgets('default grouping keeps its three groups when empty', (t) async {
    await pumpTaskPage(t, newDb());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('MISSED'), findsOneWidget);
    // Only the Today group starts expanded.
    expect(find.text('0 tasks'), findsOneWidget);
    expect(find.text('No tasks'), findsOneWidget);
  });

  testWidgets('shows the full-page empty state when grouped by day', (t) async {
    await pumpTaskPage(t, newDb(), grouping: GroupingMode.day);
    expect(find.text('No tasks here'), findsOneWidget);
    expect(find.text('Tap + to add one'), findsOneWidget);
  });

  testWidgets('lists pending tasks on the All tab', (t) async {
    final db =
        newDb()
          ..toDoList = [
            makeTask('Buy milk', dueDate: localDay(0)),
            makeTask('Call mum', dueDate: localDay(0)),
          ];
    await pumpTaskPage(t, db);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call mum'), findsOneWidget);
    expect(find.text('No tasks here'), findsNothing);
  });

  testWidgets('completed tasks are hidden from the pending list', (t) async {
    final db =
        newDb()
          ..toDoList = [
            makeTask('Open task', dueDate: localDay(0)),
            makeTask('Finished task', dueDate: localDay(0), completed: true),
          ];
    await pumpTaskPage(t, db);
    expect(find.text('Open task'), findsOneWidget);
    expect(find.text('Finished task'), findsNothing);
  });

  testWidgets('tab labels carry the pending count per tab', (t) async {
    final db =
        newDb()
          ..toDoList = [
            makeTask('a', category: 'Work', priority: 'High'),
            makeTask('b', category: 'Work', priority: 'Low'),
            makeTask('c', category: 'Study', priority: 'High', completed: true),
          ];
    await pumpTaskPage(t, db);
    expect(find.text('All  2'), findsOneWidget);
    expect(find.text('Work  2'), findsOneWidget);
    expect(find.text('High  1'), findsOneWidget);
    expect(find.text('Low  1'), findsOneWidget);
    // Study has only a completed task, so no badge.
    expect(find.text('Study'), findsOneWidget);
  });

  testWidgets('the None category does not get its own tab', (t) async {
    await pumpTaskPage(t, newDb());
    expect(find.text('None'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('hidden categories are not shown as tabs', (t) async {
    final db = newDb()..hidingCategories = ['Study'];
    await pumpTaskPage(t, db);
    expect(find.text('Study'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('the search query filters the visible tasks', (t) async {
    final db =
        newDb()
          ..toDoList = [
            makeTask('Buy milk', dueDate: localDay(0)),
            makeTask('Call mum', dueDate: localDay(0)),
          ];
    final search = await pumpTaskPage(t, db);
    search.setQuery('milk');
    await t.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call mum'), findsNothing);

    search.setQuery('');
    await t.pumpAndSettle();
    expect(find.text('Call mum'), findsOneWidget);
  });

  testWidgets('a search with no matches shows the empty state', (t) async {
    final db = newDb()..toDoList = [makeTask('Buy milk', dueDate: localDay(0))];
    final search = await pumpTaskPage(t, db);
    search.setQuery('zzz');
    await t.pumpAndSettle();
    expect(find.text('Buy milk'), findsNothing);
    expect(find.text('No tasks'), findsOneWidget);
  });

  testWidgets('switching to a category tab shows only that category', (
    t,
  ) async {
    final db =
        newDb()
          ..toDoList = [
            makeTask('Work item', category: 'Work', dueDate: localDay(0)),
            makeTask('Study item', category: 'Study', dueDate: localDay(0)),
          ];
    await pumpTaskPage(t, db);
    await t.tap(find.text('Work  1'));
    await t.pumpAndSettle();
    expect(find.text('Work item'), findsOneWidget);
    expect(find.text('Study item'), findsNothing);
  });

  testWidgets('bottom navigation shows Tasks as the current page', (t) async {
    await pumpTaskPage(t, newDb());
    final nav = t.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(nav.currentIndex, 1);
  });

  testWidgets('the add-task button opens the create sheet', (t) async {
    await pumpTaskPage(t, newDb());
    await t.tap(find.byTooltip('Add task'));
    await t.pumpAndSettle();
    expect(find.text('Add Task'), findsWidgets);
  });
}

/// A database whose task writes only touch memory, so widget tests do not
/// depend on disk I/O inside the fake-async zone.
class _MemoryDb extends ToDoDataBase {
  final List<String> writes = [];
  final List<String> cleared = [];

  @override
  Future<void> clearLocalCalTasks() async {
    localCalTasks = [];
    cleared.add('local');
  }

  @override
  Future<void> clearGoogleCalTasks() async {
    googleCalTasks = [];
    cleared.add('google');
  }

  @override
  Future<void> clearOutlookCalTasks() async {
    outlookCalTasks = [];
    cleared.add('outlook');
  }

  @override
  Future<void> saveTaskAt(int index) async => writes.add('save:$index');

  @override
  Future<void> appendTask(Task task) async => toDoList.add(task);

  @override
  Future<void> removeTaskAt(int index) async => toDoList.removeAt(index);

  @override
  Future<void> removeTasks(Iterable<Task> doomed) async {
    final set = Set<Task>.identity()..addAll(doomed);
    toDoList.removeWhere(set.contains);
  }
}

_MemoryDb memoryDb(List<Task> tasks) {
  final db =
      _MemoryDb()
        ..createInitialData()
        ..toDoList = tasks
        ..settings = const AppSettings(
          completionTone: false,
          completionAnimation: false,
        );
  return db;
}

void pastTaskCleanupTests() {
  group('removing past tasks on launch', () {
    List<Task> past(int n) => [
      for (var i = 0; i < n; i++)
        makeTask('old$i', dueDate: utcDay(-10 - i), completed: true),
    ];

    testWidgets('applies the saved limit when the page opens', (t) async {
      final db = memoryDb([
        ...past(30),
        makeTask('soon', dueDate: localDay(0)),
      ]);
      db.settings = const AppSettings(
        keepLatestPastTasks: 10,
        completionTone: false,
        completionAnimation: false,
      );
      await pumpTaskPage(t, db);
      expect(db.toDoList.length, 11);
      expect(db.toDoList.any((x) => x.name == 'soon'), isTrue);
      expect(db.toDoList.any((x) => x.name == 'old29'), isFalse);
      expect(db.toDoList.any((x) => x.name == 'old0'), isTrue);
    });

    testWidgets('does nothing when set to never remove', (t) async {
      final db = memoryDb(past(30));
      await pumpTaskPage(t, db);
      expect(db.toDoList.length, 30);
    });

    testWidgets('the tab counts reflect what was removed', (t) async {
      final db = memoryDb([
        for (var i = 0; i < 20; i++)
          makeTask('missed$i', dueDate: utcDay(-10 - i)),
        makeTask('today', dueDate: localDay(0)),
      ]);
      db.settings = const AppSettings(
        keepLatestPastTasks: 5,
        completionTone: false,
        completionAnimation: false,
      );
      await pumpTaskPage(t, db);
      // 5 kept past tasks + 1 today, all still pending.
      expect(find.text('All  6'), findsOneWidget);
    });
  });
}

dynamic pageState(WidgetTester t) => t.state(find.byType(TaskPage));

/// Lets the launch sync run. Providers that call platform plugins get their
/// "no plugin" reply on the real event loop, which the fake clock never
/// advances, so give it one short real turn; fake time moves only ~100 ms.
Future<void> settleSync(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void cacheAndSyncTests() {
  group('per-tab result cache', () {
    List<Task> some() => [
      makeTask('Alpha', dueDate: localDay(0)),
      makeTask('Beta', dueDate: localDay(0)),
    ];

    testWidgets('a rebuild with nothing changed reuses the result', (t) async {
      final db = memoryDb(some());
      await pumpTaskPage(t, db);
      final first = pageState(t).debugTabComputations as int;
      expect(first, greaterThan(0));

      // Same sort mode again: notifies, so the page rebuilds, but nothing it
      // depends on changed.
      final sorting = t.element(find.byType(TaskPage)).read<SortingProvider>();
      sorting.setMode(sorting.mode);
      await t.pumpAndSettle();
      expect(pageState(t).debugTabComputations, first);
    });

    testWidgets('changing the sort recomputes', (t) async {
      final db = memoryDb(some());
      await pumpTaskPage(t, db);
      final before = pageState(t).debugTabComputations as int;
      t
          .element(find.byType(TaskPage))
          .read<SortingProvider>()
          .setMode(SortingMode.zToa);
      await t.pumpAndSettle();
      expect(pageState(t).debugTabComputations, greaterThan(before));
      expect(
        t.getTopLeft(find.text('Beta')).dy,
        lessThan(t.getTopLeft(find.text('Alpha')).dy),
        reason: 'Z to A really applied, not a stale cached order',
      );
    });

    testWidgets('changing the grouping recomputes', (t) async {
      final db = memoryDb(some());
      await pumpTaskPage(t, db);
      final before = pageState(t).debugTabComputations as int;
      t
          .element(find.byType(TaskPage))
          .read<GroupingProvider>()
          .setMode(GroupingMode.month);
      await t.pumpAndSettle();
      expect(pageState(t).debugTabComputations, greaterThan(before));
    });

    testWidgets('a search recomputes and shows only the match', (t) async {
      final db = memoryDb(some());
      await pumpTaskPage(t, db);
      final before = pageState(t).debugTabComputations as int;
      t
          .element(find.byType(TaskPage))
          .read<SearchingProvider>()
          .setQuery('alp');
      await t.pumpAndSettle();
      expect(pageState(t).debugTabComputations, greaterThan(before));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('ticking a task recomputes (never shows a stale list)', (
      t,
    ) async {
      final db = memoryDb(some());
      await pumpTaskPage(t, db);
      final before = pageState(t).debugTabComputations as int;
      await t.tap(find.byType(Checkbox).first);
      await t.pump(const Duration(milliseconds: 1100));
      await t.pumpAndSettle();
      expect(pageState(t).debugTabComputations, greaterThan(before));
      expect(find.text('All  1'), findsOneWidget);
    });

    testWidgets('data changed behind the page is picked up', (t) async {
      final db = memoryDb(some());
      await pumpTaskPage(t, db);
      // e.g. another page on the back stack saved a new task.
      db.toDoList.add(makeTask('Gamma', dueDate: localDay(0)));
      db.dataRevision++;
      t
          .element(find.byType(TaskPage))
          .read<SortingProvider>()
          .setMode(SortingMode.aToz);
      await t.pumpAndSettle();
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('each tab keeps its own cached result', (t) async {
      final db = memoryDb([
        makeTask('Work item', category: 'Work', dueDate: localDay(0)),
        makeTask('Other item', category: 'Study', dueDate: localDay(0)),
      ]);
      await pumpTaskPage(t, db);
      await t.tap(find.text('Work  1'));
      await t.pumpAndSettle();
      expect(find.text('Work item'), findsOneWidget);
      expect(find.text('Other item'), findsNothing);

      await t.tap(find.text('All  2'));
      await t.pumpAndSettle();
      expect(find.text('Work item'), findsOneWidget);
      expect(find.text('Other item'), findsOneWidget);

      // Back to Work: served from its cache entry, not recomputed.
      final beforeBack = pageState(t).debugTabComputations as int;
      await t.tap(find.text('Work  1'));
      await t.pumpAndSettle();
      expect(pageState(t).debugTabComputations, beforeBack);
      expect(find.text('Other item'), findsNothing);
    });
  });

  group('calendar sync on launch', () {
    tearDown(AppStartup.reset);

    _MemoryDb linked() {
      final db = memoryDb([]);
      db.syncToCalendars = {'local': 'L', 'google': 'G', 'outlook': 'O'};
      return db;
    }

    testWidgets('has no artificial delays between providers', (t) async {
      await pumpTaskPage(t, linked(), settle: false);
      // The old code slept 1 s after each provider (3 s in all). Here the
      // whole sync must finish within a fraction of a second.
      await settleSync(t);
      // No platform plugins in tests, so the providers fail; the sync still
      // finishes and reports (see the next group for the wording).
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('never claims success when a provider failed', (t) async {
      await pumpTaskPage(t, linked(), settle: false);
      await settleSync(t);
      expect(find.text('Calendar synced successfully'), findsNothing);
      expect(find.text('Fix'), findsOneWidget);
      expect(find.textContaining('Google Calendar'), findsOneWidget);
    });

    testWidgets('waits for the background sign-in restore', (t) async {
      final gate = Completer<void>();
      AppStartup.ready = gate.future;
      await pumpTaskPage(t, linked(), settle: false);
      await settleSync(t);
      expect(find.byType(SnackBar), findsNothing);

      gate.complete();
      await settleSync(t);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a failing provider does not stop the sync finishing', (
      t,
    ) async {
      // In tests every provider fails (no platform plugins); the sync must
      // still complete and report.
      final syncing = <bool>[];
      await pumpTaskPage(
        t,
        linked(),
        settle: false,
        onSync: (p) => syncing.add(p.isSyncing),
      );
      await settleSync(t);
      expect(syncing, contains(true), reason: 'progress was shown');
      expect(syncing.last, isFalse, reason: 'and it finished');
    });

    testWidgets('does nothing when no calendar is linked', (t) async {
      await pumpTaskPage(t, memoryDb([]), settle: false);
      await settleSync(t);
      expect(find.text('Calendar synced successfully'), findsNothing);
    });

    testWidgets('cached events of a switched-off provider are cleared', (
      t,
    ) async {
      final db = memoryDb([]);
      db.googleCalTasks = [makeEvent('stale google')];
      db.outlookCalTasks = [makeEvent('stale outlook', source: 'outlook')];
      // local has nothing cached; all three providers are off.
      await pumpTaskPage(t, db, settle: false);
      await settleSync(t);
      expect(db.cleared.toSet(), {'google', 'outlook'});
      expect(db.googleCalTasks, isEmpty);
      expect(db.outlookCalTasks, isEmpty);
    });

    testWidgets('cached events of a linked provider are kept until replaced', (
      t,
    ) async {
      final db = linked();
      db.googleCalTasks = [makeEvent('cached google')];
      await pumpTaskPage(t, db, settle: false);
      await settleSync(t);
      expect(db.cleared, isEmpty);
      expect(
        db.googleCalTasks.single.name,
        'cached google',
        reason: 'the fetch failed, so the cache survives',
      );
    });
  });
}

void fineGrainedTests() {
  group('ticking a task rebuilds only what shows tasks', () {
    Finder addFab() => find.byTooltip('Add task');

    testWidgets('the rest of the page is not rebuilt', (t) async {
      final db = memoryDb([
        makeTask('First', dueDate: localDay(0)),
        makeTask('Second', dueDate: localDay(0)),
      ]);
      await pumpTaskPage(t, db);

      // A FloatingActionButton widget is created fresh by every page build,
      // so the same instance afterwards means the page did not rebuild.
      final fabBefore = t.widget(addFab());

      await t.tap(find.byType(Checkbox).first);
      await t.pump(const Duration(milliseconds: 1100));
      await t.pumpAndSettle();

      expect(db.toDoList.where((x) => x.completed).length, 1);
      expect(identical(t.widget(addFab()), fabBefore), isTrue);
    });

    testWidgets('the list, tab badge and storage still update', (t) async {
      final db = memoryDb([
        makeTask('First', dueDate: localDay(0)),
        makeTask('Second', dueDate: localDay(0)),
      ]);
      await pumpTaskPage(t, db);
      expect(find.text('All  2'), findsOneWidget);

      await t.tap(find.byType(Checkbox).first);
      await t.pump(const Duration(milliseconds: 1100));
      await t.pumpAndSettle();

      expect(find.text('All  1'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(db.writes, ['save:0'], reason: 'one record written');
    });

    testWidgets('the completed-tasks button hides while the tick animates', (
      t,
    ) async {
      final db = memoryDb([makeTask('First', dueDate: localDay(0))]);
      await pumpTaskPage(t, db);
      expect(find.byTooltip('Show completed'), findsOneWidget);

      await t.tap(find.byType(Checkbox).first);
      await t.pump(); // the switcher starts its cross-fade on this frame
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Show completed'), findsNothing);

      await t.pump(const Duration(milliseconds: 1000));
      await t.pumpAndSettle();
      expect(find.byTooltip('Show completed'), findsOneWidget);
    });

    testWidgets('a provider-driven change refreshes the lists', (t) async {
      final db = memoryDb([makeTask('Old', dueDate: localDay(0))]);
      await pumpTaskPage(t, db);
      db.toDoList.add(makeTask('Brand new', dueDate: localDay(0)));
      t.element(find.byType(TaskPage)).read<DataProvider>().markTasksChanged();
      await t.pumpAndSettle();
      expect(find.text('Brand new'), findsOneWidget);
      expect(find.text('All  2'), findsOneWidget);
    });

    testWidgets('changing the sort still rebuilds the whole page', (t) async {
      final db = memoryDb([makeTask('A', dueDate: localDay(0))]);
      await pumpTaskPage(t, db);
      final fabBefore = t.widget(addFab());
      t
          .element(find.byType(TaskPage))
          .read<SortingProvider>()
          .setMode(SortingMode.aToz);
      await t.pumpAndSettle();
      expect(identical(t.widget(addFab()), fabBefore), isFalse);
    });
  });
}
