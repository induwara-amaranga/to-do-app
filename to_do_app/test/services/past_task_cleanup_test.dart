import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/past_task_cleanup.dart';
import 'package:to_do_app/services/repeat_task.dart';

import '../helpers/test_data.dart';

class _FakeContext extends Fake implements BuildContext {}

/// A fixed "now" so the tests do not depend on the day they run.
final now = DateTime.utc(2026, 6, 15, 12);

String day(int daysFromNow) {
  final d = DateTime.utc(2026, 6, 15).add(Duration(days: daysFromNow));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// [count] past tasks due on consecutive days, newest at -3 days (older
/// than the one-day safety margin). Names are `p0` (newest) to `p{n-1}`.
List<Task> pastTasks(int count, {bool completed = false}) => [
  for (var i = 0; i < count; i++)
    makeTask('p$i', dueDate: day(-3 - i), completed: completed),
];

List<String> names(Iterable<Task> t) => t.map((x) => x.name).toList();

void main() {
  setUpAll(initTestTimeZone);

  group('options', () {
    test('offers never plus 500, 1000 and 2000', () {
      expect(PastTaskCleanup.options.keys.toList(), [0, 500, 1000, 2000]);
      expect(PastTaskCleanup.options[0], 'Never remove');
      expect(PastTaskCleanup.options[500], 'Keep latest 500 tasks');
      expect(PastTaskCleanup.options[1000], 'Keep latest 1000 tasks');
      expect(PastTaskCleanup.options[2000], 'Keep latest 2000 tasks');
    });

    test('labels round-trip and tolerate odd values', () {
      expect(PastTaskCleanup.label(500), 'Keep latest 500 tasks');
      expect(PastTaskCleanup.label(0), 'Never remove');
      expect(PastTaskCleanup.label(42), 'Keep latest 42 tasks');
    });
  });

  group('selectRemovable', () {
    test('never remove: nothing is selected, however many tasks', () {
      expect(
        PastTaskCleanup.selectRemovable(pastTasks(3000), 0, now: now),
        isEmpty,
      );
    });

    test('a negative limit is treated as never', () {
      expect(
        PastTaskCleanup.selectRemovable(pastTasks(10), -5, now: now),
        isEmpty,
      );
    });

    test('at or under the limit removes nothing', () {
      expect(
        PastTaskCleanup.selectRemovable(pastTasks(500), 500, now: now),
        isEmpty,
      );
      expect(
        PastTaskCleanup.selectRemovable(pastTasks(499), 500, now: now),
        isEmpty,
      );
    });

    test('over the limit removes exactly the excess, oldest first', () {
      final tasks = pastTasks(503);
      final doomed = PastTaskCleanup.selectRemovable(tasks, 500, now: now);
      expect(doomed.length, 3);
      // p502 is the oldest, then p501, then p500.
      expect(names(doomed), ['p502', 'p501', 'p500']);
    });

    test('the newest past tasks are the ones kept', () {
      final tasks = pastTasks(10);
      final doomed = PastTaskCleanup.selectRemovable(tasks, 4, now: now);
      final kept = tasks.where((t) => !doomed.contains(t));
      expect(names(kept), ['p0', 'p1', 'p2', 'p3']);
    });

    test('list order does not matter, due date does', () {
      final shuffled = pastTasks(8).reversed.toList();
      final doomed = PastTaskCleanup.selectRemovable(shuffled, 5, now: now);
      expect(names(doomed).toSet(), {'p5', 'p6', 'p7'});
    });

    test('time of day orders tasks within the same date', () {
      final tasks = [
        makeTask('early', dueDate: day(-5), dueTime: '06:00'),
        makeTask('late', dueDate: day(-5), dueTime: '22:00'),
      ];
      final doomed = PastTaskCleanup.selectRemovable(tasks, 1, now: now);
      expect(names(doomed), ['early']);
    });

    test('ties are broken by list order, deterministically', () {
      final tasks = [
        for (var i = 0; i < 4; i++) makeTask('t$i', dueDate: day(-9)),
      ];
      final a = PastTaskCleanup.selectRemovable(tasks, 2, now: now);
      final b = PastTaskCleanup.selectRemovable(tasks, 2, now: now);
      expect(names(a), names(b));
      expect(a.length, 2);
    });

    test('completed and missed past tasks are treated alike', () {
      final tasks = [
        ...pastTasks(3, completed: true),
        makeTask('missed', dueDate: day(-30), completed: false),
        makeTask('done-old', dueDate: day(-40), completed: true),
      ];
      final doomed = PastTaskCleanup.selectRemovable(tasks, 3, now: now);
      expect(names(doomed), ['done-old', 'missed']);
    });

    test('upcoming tasks are never removed', () {
      final tasks = [
        ...pastTasks(5),
        makeTask('future', dueDate: day(10)),
        makeTask('far future', dueDate: day(900)),
      ];
      final doomed = PastTaskCleanup.selectRemovable(tasks, 1, now: now);
      expect(names(doomed), isNot(contains('future')));
      expect(names(doomed), isNot(contains('far future')));
      expect(doomed.length, 4);
    });

    test('tasks with no usable due date are never removed', () {
      final tasks = [
        ...pastTasks(5),
        makeTask('none', dueDate: null),
        makeTask('empty', dueDate: ''),
        makeTask('zeros', dueDate: '0000-00-00'),
        makeTask('garbage', dueDate: 'not a date'),
      ];
      final doomed = PastTaskCleanup.selectRemovable(tasks, 1, now: now);
      expect(
        names(
          doomed,
        ).toSet().intersection({'none', 'empty', 'zeros', 'garbage'}),
        isEmpty,
      );
      expect(doomed.length, 4);
    });

    test('today and yesterday (UTC) are inside the safety margin', () {
      final tasks = [
        makeTask('today', dueDate: day(0)),
        makeTask('yesterday', dueDate: day(-1)),
        makeTask('two days ago', dueDate: day(-2)),
      ];
      // keep 0 would remove nothing, so ask to keep 1 of the "past" ones.
      final doomed = PastTaskCleanup.selectRemovable(tasks, 1, now: now);
      expect(names(doomed), isEmpty, reason: 'only one task counts as past');
    });

    test('only tasks past the margin count toward the limit', () {
      final tasks = [
        makeTask('today', dueDate: day(0)),
        makeTask('yesterday', dueDate: day(-1)),
        makeTask('old a', dueDate: day(-2)),
        makeTask('old b', dueDate: day(-3)),
      ];
      final doomed = PastTaskCleanup.selectRemovable(tasks, 1, now: now);
      expect(names(doomed), ['old b']);
    });

    test('a bad due time does not break selection', () {
      final tasks = [
        makeTask('a', dueDate: day(-5), dueTime: 'xx:yy'),
        makeTask('b', dueDate: day(-6), dueTime: null),
        makeTask('c', dueDate: day(-7), dueTime: '25:99'),
      ];
      expect(
        () => PastTaskCleanup.selectRemovable(tasks, 1, now: now),
        returnsNormally,
      );
      expect(PastTaskCleanup.selectRemovable(tasks, 1, now: now).length, 2);
    });

    test('does not modify the list it is given', () {
      final tasks = pastTasks(20);
      final before = List<Task>.of(tasks);
      PastTaskCleanup.selectRemovable(tasks, 5, now: now);
      expect(tasks, before);
    });

    test('empty list', () {
      expect(PastTaskCleanup.selectRemovable([], 500, now: now), isEmpty);
    });
  });

  group('run', () {
    late TestDb env;
    late ToDoDataBase db;

    setUp(() async {
      env = await TestDb.open();
      db = env.db;
    });
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      await env.dispose();
    });

    Future<void> seed(List<Task> tasks, {int keep = 500}) async {
      db.toDoList = tasks;
      await db.saveToDoList();
      db.settings = AppSettings(keepLatestPastTasks: keep);
    }

    test('does nothing while the setting is Never', () async {
      await seed(pastTasks(30), keep: 0);
      expect(await PastTaskCleanup.run(db, now: now), 0);
      expect(db.toDoList.length, 30);
    });

    test('removes the excess from memory and from disk', () async {
      await seed([
        ...pastTasks(12),
        makeTask('future', dueDate: day(5)),
      ], keep: 10);
      final removed = await PastTaskCleanup.run(db, now: now);
      expect(removed, 2);
      expect(db.toDoList.length, 11);
      expect(names(db.toDoList), isNot(contains('p10')));
      expect(names(db.toDoList), isNot(contains('p11')));
      expect(names(db.toDoList), contains('future'));

      // Gone from the box too, not just the list.
      db.loadToDoList();
      expect(db.toDoList.length, 11);
    });

    test('keeps the order of everything that remains', () async {
      await seed([
        makeTask('keep1', dueDate: day(-3)),
        makeTask('drop', dueDate: day(-50)),
        makeTask('keep2', dueDate: day(-4)),
        makeTask('upcoming', dueDate: day(3)),
      ], keep: 2);
      await PastTaskCleanup.run(db, now: now);
      expect(names(db.toDoList), ['keep1', 'keep2', 'upcoming']);
      db.loadToDoList();
      expect(names(db.toDoList), ['keep1', 'keep2', 'upcoming']);
    });

    test('is idempotent', () async {
      await seed(pastTasks(20), keep: 10);
      expect(await PastTaskCleanup.run(db, now: now), 10);
      expect(await PastTaskCleanup.run(db, now: now), 0);
      expect(db.toDoList.length, 10);
    });

    test('cancels the reminders of removed tasks only', () async {
      final old = makeTask('old', dueDate: day(-50))..notificationIds = [7, 8];
      final recent = makeTask('recent', dueDate: day(-3))
        ..notificationIds = [9];
      await seed([recent, old], keep: 1);
      final cancelled = <int>[];
      await PastTaskCleanup.run(
        db,
        now: now,
        cancelNotification: (id) async => cancelled.add(id),
      );
      expect(cancelled, [7, 8]);
    });

    test('a failing reminder cancel does not stop the cleanup', () async {
      final old = makeTask('old', dueDate: day(-50))..notificationIds = [1, 2];
      await seed([makeTask('recent', dueDate: day(-3)), old], keep: 1);
      final removed = await PastTaskCleanup.run(
        db,
        now: now,
        cancelNotification: (_) async => throw Exception('plugin missing'),
      );
      expect(removed, 1);
      expect(names(db.toDoList), ['recent']);
    });

    test('uses the limit saved in settings', () async {
      await seed(pastTasks(30), keep: 25);
      expect(await PastTaskCleanup.run(db, now: now), 5);
      db.settings = const AppSettings(keepLatestPastTasks: 10);
      expect(await PastTaskCleanup.run(db, now: now), 15);
      expect(db.toDoList.length, 10);
    });
  });

  group('ToDoDataBase.removeTasks', () {
    late TestDb env;
    setUp(() async => env = await TestDb.open());
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      await env.dispose();
    });

    test('removes a batch with a single bulk delete', () async {
      final db = env.db;
      for (final n in ['a', 'b', 'c', 'd', 'e']) {
        await db.appendTask(makeTask(n));
      }
      final doomed = [db.toDoList[1], db.toDoList[3]];
      await db.removeTasks(doomed);
      expect(names(db.toDoList), ['a', 'c', 'e']);
      db.loadToDoList();
      expect(names(db.toDoList), ['a', 'c', 'e']);
    });

    test('an empty batch is a no-op', () async {
      await env.db.appendTask(makeTask('a'));
      await env.db.removeTasks([]);
      expect(env.db.toDoList.length, 1);
    });

    test('tasks that are not in the list are ignored', () async {
      await env.db.appendTask(makeTask('a'));
      await env.db.removeTasks([makeTask('stranger')]);
      expect(names(env.db.toDoList), ['a']);
    });
  });

  group('repeating tasks', () {
    late TestDb env;
    setUp(() async => env = await TestDb.open());
    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      await env.dispose();
    });

    test(
      'removed old occurrences are not recreated by the launch catch-up',
      () async {
        final db = env.db;
        // A daily task with an occurrence for each of the last 40 days.
        final series = [
          for (var i = 40; i >= 0; i--)
            makeTask('Water plants', dueDate: utcDay(-i), repeatType: 'daily'),
        ];
        await db.appendTask(series.first);
        for (final t in series.skip(1)) {
          await db.appendTask(t);
        }

        final doomed = PastTaskCleanup.selectRemovable(db.toDoList, 10);
        expect(doomed, isNotEmpty);
        final removedDates = doomed.map((t) => t.dueDate).toSet();
        await db.removeTasks(doomed);

        await RepeatTask.createPendingRepeatTasks(db, _FakeContext());
        await Future.delayed(const Duration(milliseconds: 100));

        final datesNow = db.toDoList.map((t) => t.dueDate).toSet();
        expect(
          datesNow.intersection(removedDates),
          isEmpty,
          reason: 'catch-up must not bring deleted history back',
        );
      },
    );

    test(
      'a repeating series keeps producing future tasks after cleanup',
      () async {
        final db = env.db;
        for (var i = 20; i >= 3; i--) {
          await db.appendTask(
            makeTask('Gym', dueDate: utcDay(-i), repeatType: 'daily'),
          );
        }
        db.settings = const AppSettings(keepLatestPastTasks: 5);
        await PastTaskCleanup.run(db);
        await RepeatTask.createPendingRepeatTasks(db, _FakeContext());
        await Future.delayed(const Duration(milliseconds: 100));

        final dates = db.toDoList.map((t) => t.dueDate!).toList()..sort();
        expect(
          dates.last.compareTo(utcDay(0)) >= 0,
          isTrue,
          reason: 'the series still reaches today or later',
        );
      },
    );
  });
}
