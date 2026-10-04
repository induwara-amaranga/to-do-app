// Performance checks against ~1000 generated tasks.
//
// Budgets are deliberately loose (roughly 5-20x what a laptop needs) so the
// suite catches algorithmic regressions (an accidental O(n^2), a sort that
// re-parses dates per comparison, a list that builds every tile) without
// failing on a slow CI box. Every measurement is printed, so run with
// `flutter test test/performance` to see the real numbers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/task_tile.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/pages/task_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/providers/data_provider.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/services/filter_tasks_service.dart';
import 'package:to_do_app/services/group_tasks_service.dart';
import 'package:to_do_app/services/repeat_task.dart';
import 'package:to_do_app/services/search_tasks.dart';
import 'package:to_do_app/services/sort_tasks_service.dart';
import 'package:to_do_app/themes/light_mode.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

import '../helpers/test_data.dart';

const int kCount = 1000;

/// Deterministic mock data: mixed categories, priorities, due dates from a
/// year ago to a year ahead, ~30% completed, ~10% starred, some with notes
/// and subtasks, and `todayCount` tasks due today so the default grouping has
/// a large expanded group.
List<Task> mockTasks({int count = kCount, int todayCount = 0}) {
  var seed = 42;
  int next(int max) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % max;
  }

  const categories = ['None', 'Work', 'Personal', 'Study', 'Others'];
  const priorities = ['Low', 'Medium', 'High'];
  const words = ['report', 'milk', 'gym', 'rent', 'email', 'call', 'plan'];
  final base = DateTime.utc(2025, 1, 1);

  return List.generate(count, (i) {
    final isToday = i < todayCount;
    final due = isToday ? utcDay(0) : _day(base.add(Duration(days: next(730) - 365)));
    final hour = next(24).toString().padLeft(2, '0');
    final minute = (next(4) * 15).toString().padLeft(2, '0');
    return makeTask(
      '${words[next(words.length)]} task $i',
      dueDate: due,
      dueTime: '$hour:$minute',
      category: categories[next(categories.length)],
      priority: priorities[next(priorities.length)],
      completed: !isToday && next(10) < 3,
      isStarred: next(10) == 0,
      note: next(2) == 0 ? 'note about ${words[next(words.length)]}' : null,
      createdAt:
          base.add(Duration(hours: next(8000))).toIso8601String(),
      subtasks: next(4) == 0 ? [SubTask(name: 'sub a'), SubTask(name: 'sub b')] : null,
    );
  });
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Runs [body] [runs] times and returns the best (lowest) time in ms, which
/// is the least noisy estimate. Prints the result.
double measure(String label, void Function() body, {int runs = 3}) {
  body(); // warm-up: JIT, caches
  var best = double.infinity;
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    final ms = sw.elapsedMicroseconds / 1000;
    if (ms < best) best = ms;
  }
  // ignore: avoid_print
  print('[perf] ${label.padRight(46)} ${best.toStringAsFixed(2).padLeft(9)} ms');
  return best;
}

Future<double> measureAsync(String label, Future<void> Function() body) async {
  final sw = Stopwatch()..start();
  await body();
  sw.stop();
  final ms = sw.elapsedMicroseconds / 1000;
  // ignore: avoid_print
  print('[perf] ${label.padRight(46)} ${ms.toStringAsFixed(2).padLeft(9)} ms');
  return ms;
}

void main() {
  setUpAll(initTestTimeZone);

  late List<Task> tasks;
  setUp(() => tasks = mockTasks());

  test('mock data has the expected shape', () {
    expect(tasks.length, kCount);
    expect(tasks.map((t) => t.id).toSet().length, kCount);
    expect(tasks.where((t) => t.completed).length, inInclusiveRange(200, 400));
    expect(tasks.map((t) => t.category).toSet().length, 5);
  });

  group('in-memory task pipeline ($kCount tasks)', () {
    test('every sort mode', () {
      for (final mode in SortingMode.values) {
        final ms = measure(
          'sort ${mode.name}',
          () => SortTasksService.sortTasksByMode(tasks, mode),
        );
        expect(ms, lessThan(250), reason: '$mode');
      }
    });

    test('sorting does not reorder or copy-mutate the source', () {
      final before = List<Task>.of(tasks);
      for (final mode in SortingMode.values) {
        SortTasksService.sortTasksByMode(tasks, mode);
      }
      expect(tasks, before);
    });

    test('every grouping mode', () {
      for (final mode in GroupingMode.values) {
        final ms = measure(
          'group ${mode.name}',
          () => GroupTasksService.groupTasksByMode(tasks, mode, false),
        );
        expect(ms, lessThan(250), reason: '$mode');
      }
    });

    test('grouping keeps every task exactly once', () {
      for (final mode in GroupingMode.values) {
        final grouped = GroupTasksService.groupTasksByMode(tasks, mode, false);
        final total = grouped.values.fold<int>(0, (a, b) => a + b.length);
        expect(total, kCount, reason: '$mode');
      }
    });

    test('search by name and note', () {
      final ms = measure('search "milk"', () => SearchTasks.searchByQuery('milk', tasks));
      expect(ms, lessThan(100));
      final noHit = measure(
        'search (no match)',
        () => SearchTasks.searchByQuery('zzzzzz', tasks),
      );
      expect(noHit, lessThan(100));
    });

    test('category and status filter', () {
      final ms = measure(
        'filter categories + Pending',
        () => FilterTasksService.filterTasksByCategory(tasks, {
          'categories': ['Work', 'High', 'Pending'],
          'selectedDueDates': <DateTime>[],
          'selectedFilter': 'Selected_dates',
        }),
      );
      expect(ms, lessThan(500));
    });

    test('date-range filter', () {
      final ms = measure(
        'filter Before date',
        () => FilterTasksService.filterTasksByCategory(tasks, {
          'categories': <String>[],
          'selectedDueDates': [DateTime.utc(2025, 6, 1)],
          'selectedFilter': 'Before',
        }),
      );
      expect(ms, lessThan(500));
    });

    test('the full tab pipeline (filter, search, sort, group)', () {
      final ms = measure('filter+search+sort+group', () {
        var list = tasks.where((t) => !t.completed && t.category == 'Work').toList();
        list = SearchTasks.searchByQuery('task', list);
        list = SortTasksService.sortTasksByMode(list, SortingMode.dueDateIncreasing);
        GroupTasksService.groupTasksByMode(list, GroupingMode.Default, false);
      });
      expect(ms, lessThan(300));
    });

    test('sorting scales roughly n log n, not quadratic', () {
      final small = mockTasks(count: 250);
      final large = mockTasks(count: 1000);
      final tSmall = measure(
        'sort due date x250',
        () => SortTasksService.sortTasksByMode(small, SortingMode.dueDateIncreasing),
        runs: 5,
      );
      final tLarge = measure(
        'sort due date x1000',
        () => SortTasksService.sortTasksByMode(large, SortingMode.dueDateIncreasing),
        runs: 5,
      );
      // 4x the data: n log n predicts ~5x; quadratic would be 16x. Allow a
      // wide margin (and a floor, since sub-millisecond timings are noise).
      expect(tLarge, lessThan(tSmall * 12 + 5));
    });

    test('date parsing is cached', () {
      final dates = tasks.map((t) => t.dueDate).toList();
      final cold = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        for (final d in dates) {
          DateTimeUtilsHelper.parseDate(d);
        }
      }
      cold.stop();
      // ignore: avoid_print
      print('[perf] ${'parseDate x${dates.length * 20}'.padRight(46)} '
          '${(cold.elapsedMicroseconds / 1000).toStringAsFixed(2).padLeft(9)} ms');
      expect(cold.elapsedMilliseconds, lessThan(500));
    });

    test('time zone conversion of every task', () {
      final ms = measure(
        'toLocalUsingTz x$kCount',
        () {
          for (final t in tasks) {
            DateTimeUtilsHelper.toLocalUsingTz(
              DateTimeUtilsHelper.combineDateAndTimeFromStrings(
                t.dueDate!,
                t.dueTime!,
              ),
            );
          }
        },
      );
      expect(ms, lessThan(300));
    });
  });

  group('database ($kCount tasks, real Hive on disk)', () {
    late TestDb env;
    late ToDoDataBase db;

    setUp(() async {
      env = await TestDb.open();
      db = env.db;
      db.toDoList = mockTasks();
    });
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      await env.dispose();
    });

    test('full save of the task box', () async {
      final ms = await measureAsync('saveToDoList x$kCount', db.saveToDoList);
      expect(ms, lessThan(5000));
    });

    test('load from disk', () async {
      await db.saveToDoList();
      final ms = await measureAsync('loadToDoList x$kCount', () async => db.loadToDoList());
      expect(ms, lessThan(1000));
      expect(db.toDoList.length, kCount);
    });

    test('data survives a save and reload intact', () async {
      final expected = db.toDoList.map((t) => '${t.id}|${t.name}|${t.dueDate}').toList();
      await db.saveToDoList();
      db.loadToDoList();
      expect(
        db.toDoList.map((t) => '${t.id}|${t.name}|${t.dueDate}').toList(),
        expected,
      );
    });

    test('a single-task edit is much cheaper than a full rewrite', () async {
      await db.saveToDoList();
      final full = await measureAsync('full rewrite (1 edit)', db.saveToDoList);

      final times = <double>[];
      for (var i = 0; i < 10; i++) {
        db.toDoList[i * 50].completed = !db.toDoList[i * 50].completed;
        final sw = Stopwatch()..start();
        await db.saveTaskAt(i * 50);
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000);
      }
      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('[perf] ${'saveTaskAt (avg of 10)'.padRight(46)} ${avg.toStringAsFixed(2).padLeft(9)} ms');
      expect(avg, lessThan(full), reason: 'per-record save should beat a rewrite');
    });

    test('append and remove stay fast on a large box', () async {
      await db.saveToDoList();
      final add = await measureAsync(
        'appendTask (on $kCount)',
        () => db.appendTask(makeTask('extra')),
      );
      final rm = await measureAsync(
        'removeTaskAt (on ${kCount + 1})',
        () => db.removeTaskAt(500),
      );
      expect(add, lessThan(500));
      expect(rm, lessThan(500));
      expect(db.toDoList.length, kCount);
    });

    test('100 sequential per-task saves', () async {
      await db.saveToDoList();
      final ms = await measureAsync('100x saveTaskAt', () async {
        for (var i = 0; i < 100; i++) {
          await db.saveTaskAt(i);
        }
      });
      expect(ms, lessThan(5000));
    });

    test('calendar boxes with 1000 events each', () async {
      db.localCalTasks = List.generate(kCount, (i) => makeEvent('l$i', source: 'local'));
      db.googleCalTasks = List.generate(kCount, (i) => makeEvent('g$i'));
      db.outlookCalTasks = List.generate(kCount, (i) => makeEvent('o$i', source: 'outlook'));
      final ms = await measureAsync('updateDataBase (1000 tasks + 3000 events)', db.updateDataBase);
      expect(ms, lessThan(10000));
    });

    test('cold start: reopen the boxes and load 1000 tasks', () async {
      db.runMigrations();
      await db.updateDataBase();
      await Hive.close();
      Hive.init(env.dir.path);
      final fresh = ToDoDataBase();
      final ms = await measureAsync('openBoxes + loadData', () async {
        await fresh.openBoxes();
        fresh.loadData();
      });
      expect(fresh.toDoList.length, kCount);
      expect(ms, lessThan(2000));
    });
  });

  group('DataProvider ($kCount tasks)', () {
    late TestDb env;
    setUp(() async {
      env = await TestDb.open();
      env.db.toDoList = mockTasks();
    });
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      await env.dispose();
    });

    test('addTask on a large list', () async {
      final provider = DataProvider(env.db);
      final ms = await measureAsync('DataProvider.addTask', () => provider.addTask(makeTask('x')));
      expect(ms, lessThan(5000));
      expect(provider.tasks.length, kCount + 1);
    });
  });

  group('repeat tasks catch-up', () {
    late TestDb env;
    setUp(() async => env = await TestDb.open());
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      await env.dispose();
    });

    test('100 daily tasks, each a year behind', () async {
      final ctx = _FakeContext();
      for (var i = 0; i < 100; i++) {
        env.db.toDoList.add(
          makeTask('daily $i', dueDate: utcDay(-365), repeatType: 'daily'),
        );
      }
      final ms = await measureAsync('createPendingRepeatTasks (~36k adds)', () async {
        RepeatTask.createPendingRepeatTasks(env.db, ctx);
        await pumpEventQueue(times: 60000);
      });
      // ~366 occurrences x 100 tasks. The duplicate check is a set lookup;
      // a list scan per occurrence would be ~36,000 x 36,000 comparisons.
      expect(env.db.toDoList.length, greaterThan(30000));
      expect(ms, lessThan(60000));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('TaskPage rendering ($kCount tasks)', () {
    Future<void> pumpPage(
      WidgetTester t,
      ToDoDataBase db, {
      GroupingMode grouping = GroupingMode.Default,
    }) async {
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => GroupingProvider()..setMode(grouping),
            ),
            ChangeNotifierProvider(create: (_) => SortingProvider()),
            ChangeNotifierProvider(create: (_) => SearchingProvider()),
            ChangeNotifierProvider(create: (_) => CalendarSyncProvider()),
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
    }

    ToDoDataBase dbWith(List<Task> list) {
      final db = ToDoDataBase()..createInitialData();
      db.toDoList = list;
      return db;
    }

    testWidgets('first render builds only the visible tiles', (t) async {
      final db = dbWith(mockTasks(todayCount: 300));
      final sw = Stopwatch()..start();
      await pumpPage(t, db);
      await t.pumpAndSettle();
      sw.stop();
      // ignore: avoid_print
      print('[perf] ${'TaskPage first render (300 due today)'.padRight(46)} '
          '${sw.elapsedMilliseconds.toString().padLeft(9)} ms');

      final built = find.byType(TaskTile).evaluate().length;
      // ignore: avoid_print
      print('[perf] ${'TaskTile widgets built'.padRight(46)} ${built.toString().padLeft(9)}');
      expect(built, greaterThan(0));
      expect(built, lessThan(60), reason: 'the list must build lazily');
      expect(sw.elapsedMilliseconds, lessThan(10000));
    });

    testWidgets('scrolling a long list stays lazy', (t) async {
      final db = dbWith(mockTasks(todayCount: 300));
      await pumpPage(t, db);
      await t.pumpAndSettle();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 10; i++) {
        await t.drag(find.byType(Scrollable).last, const Offset(0, -800));
        await t.pump();
      }
      sw.stop();
      // ignore: avoid_print
      print('[perf] ${'10 scroll flicks'.padRight(46)} ${sw.elapsedMilliseconds.toString().padLeft(9)} ms');
      expect(find.byType(TaskTile).evaluate().length, lessThan(60));
      expect(sw.elapsedMilliseconds, lessThan(10000));
    });

    testWidgets('typing in search re-filters 1000 tasks quickly', (t) async {
      final db = dbWith(mockTasks(todayCount: 300));
      await pumpPage(t, db);
      await t.pumpAndSettle();
      final search = Provider.of<SearchingProvider>(
        t.element(find.byType(TaskPage)),
        listen: false,
      );

      final sw = Stopwatch()..start();
      for (final q in ['m', 'mi', 'mil', 'milk']) {
        search.setQuery(q);
        await t.pump();
      }
      sw.stop();
      // ignore: avoid_print
      print('[perf] ${'4 keystrokes of search'.padRight(46)} ${sw.elapsedMilliseconds.toString().padLeft(9)} ms');
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    testWidgets('grouped by day: only expanded groups build tiles', (t) async {
      final db = dbWith(mockTasks());
      final sw = Stopwatch()..start();
      await pumpPage(t, db, grouping: GroupingMode.day);
      await t.pumpAndSettle();
      sw.stop();
      // ignore: avoid_print
      print('[perf] ${'TaskPage grouped by day (1000 tasks)'.padRight(46)} '
          '${sw.elapsedMilliseconds.toString().padLeft(9)} ms');
      expect(find.byType(TaskTile).evaluate().length, lessThan(60));
      expect(sw.elapsedMilliseconds, lessThan(10000));
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}
