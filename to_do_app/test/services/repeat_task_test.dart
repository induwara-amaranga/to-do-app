import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/services/repeat_task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

import '../helpers/test_data.dart';

class _FakeContext extends Fake implements BuildContext {}

void main() {
  late TestDb env;
  final ctx = _FakeContext();

  setUpAll(initTestTimeZone);
  setUp(() async => env = await TestDb.open());
  tearDown(() async {
    // RepeatTask fires db.saveToDoList() without awaiting it; let that
    // finish before the box is closed.
    await Future.delayed(const Duration(milliseconds: 200));
    await env.dispose();
  });

  group('RepeatTask.createNextRepeatTask', () {
    test('daily task due today spawns tomorrow\'s copy', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask(
          'Gym',
          dueDate: utcDay(0),
          repeatType: 'daily',
          category: 'Health',
          priority: 'High',
          isStarred: true,
          note: 'legs',
          subtasks: [SubTask(name: 'warm up')],
        ),
      );

      await RepeatTask.createNextRepeatTask(ctx, 0, db);

      expect(db.toDoList.length, 2);
      final next = db.toDoList.last;
      expect(next.dueDate, utcDay(1));
      expect(next.name, 'Gym');
      expect(next.category, 'Health');
      expect(next.priority, 'High');
      expect(next.isStarred, isTrue);
      expect(next.note, 'legs');
      expect(next.repeatType, 'daily');
      expect(next.source, 'repeat');
      expect(next.completed, isFalse);
      expect(next.completedAt, 'none');
      expect(next.subtasks.single.name, 'warm up');
      expect(next.id, isNot(db.toDoList.first.id));
    });

    test('weekly adds seven days', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Review', dueDate: utcDay(0), repeatType: 'weekly'),
      );
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      expect(db.toDoList.last.dueDate, utcDay(7));
    });

    test('monthly moves to the same day next month', () async {
      final db = env.db;
      final today = DateTime.now().toUtc();
      // Day 15 exists in every month, so there is no overflow to worry about.
      final due = DateTime(today.year, today.month, 15);
      db.toDoList.add(
        makeTask(
          'Rent',
          dueDate: DateTimeUtilsHelper.formatDate(due),
          repeatType: 'monthly',
        ),
      );
      // Due date may be in the past this month; only run the future case.
      if (due.isBefore(DateTime(today.year, today.month, today.day))) {
        db.toDoList.first.dueDate = utcDay(0);
      }
      final base = DateTimeUtilsHelper.parseDate(db.toDoList.first.dueDate)!;
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      final expected = DateTime(base.year, base.month + 1, base.day);
      expect(
        db.toDoList.last.dueDate,
        DateTimeUtilsHelper.formatDate(expected),
      );
    });

    test('yearly moves to the same date next year', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Birthday', dueDate: utcDay(0), repeatType: 'yearly'),
      );
      final base = DateTimeUtilsHelper.parseDate(db.toDoList.first.dueDate)!;
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      final expected = DateTime(base.year + 1, base.month, base.day);
      expect(
        db.toDoList.last.dueDate,
        DateTimeUtilsHelper.formatDate(expected),
      );
    });

    test('does nothing when the due date is already in the past', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Old', dueDate: utcDay(-4), repeatType: 'daily'),
      );
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      expect(db.toDoList.length, 1);
    });

    test('does nothing for repeat type "none"', () async {
      final db = env.db;
      db.toDoList.add(makeTask('Once', dueDate: utcDay(0), repeatType: 'none'));
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      expect(db.toDoList.length, 1);
    });

    test('does not create a duplicate occurrence', () async {
      final db = env.db;
      db.toDoList.add(makeTask('Gym', dueDate: utcDay(0), repeatType: 'daily'));
      db.toDoList.add(makeTask('Gym', dueDate: utcDay(1), repeatType: 'daily'));
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      expect(db.toDoList.length, 2);
    });

    test('a task with an unparseable due date is ignored', () async {
      final db = env.db;
      db.toDoList.add(makeTask('Bad', dueDate: 'garbage', repeatType: 'daily'));
      await RepeatTask.createNextRepeatTask(ctx, 0, db);
      expect(db.toDoList.length, 1);
    });
  });

  group('RepeatTask.createPendingRepeatTasks (catch-up on launch)', () {
    Future<void> run() async {
      RepeatTask.createPendingRepeatTasks(env.db, ctx);
      await pumpEventQueue(times: 200);
    }

    test('backfills every missed daily occurrence up to today', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Water plants', dueDate: utcDay(-3), repeatType: 'daily'),
      );
      await run();

      final dates = db.toDoList.map((t) => t.dueDate).toList();
      expect(dates, containsAll([utcDay(-3), utcDay(-2), utcDay(-1)]));
      expect(dates.toSet().length, dates.length, reason: 'no duplicates');
      expect(
        db.toDoList.skip(1).every((t) => t.source == 'repeat' && !t.completed),
        isTrue,
      );
    });

    test('is idempotent: a second run adds nothing', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Water plants', dueDate: utcDay(-3), repeatType: 'daily'),
      );
      await run();
      final countAfterFirst = db.toDoList.length;
      await run();
      expect(db.toDoList.length, countAfterFirst);
    });

    test('weekly tasks are backfilled in seven day steps', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Laundry', dueDate: utcDay(-15), repeatType: 'weekly'),
      );
      await run();
      final dates = db.toDoList.map((t) => t.dueDate).toSet();
      expect(dates, containsAll([utcDay(-15), utcDay(-8), utcDay(-1)]));
    });

    test('tasks that do not repeat are left alone', () async {
      final db = env.db;
      db.toDoList.add(makeTask('One-off', dueDate: utcDay(-3)));
      await run();
      expect(db.toDoList.length, 1);
    });

    test('future repeating tasks are left alone', () async {
      final db = env.db;
      db.toDoList.add(
        makeTask('Later', dueDate: utcDay(10), repeatType: 'daily'),
      );
      await run();
      expect(db.toDoList.length, 1);
    });

    test('an existing occurrence is not duplicated', () async {
      final db = env.db;
      db.toDoList
        ..add(makeTask('Gym', dueDate: utcDay(-2), repeatType: 'daily'))
        ..add(makeTask('Gym', dueDate: utcDay(-1), repeatType: 'daily'));
      await run();
      final onYesterday = db.toDoList.where((t) => t.dueDate == utcDay(-1));
      expect(onYesterday.length, 1);
    });
  });

  group('NotificationService.remainderDateTime', () {
    final due = DateTime(2025, 3, 10);
    final time = DateTime(1970, 1, 1, 14, 30);

    test('minutes', () {
      expect(
        NotificationService.remainderDateTime(due, time, 'minutes', 15),
        DateTime(2025, 3, 10, 14, 15),
      );
    });

    test('hours', () {
      expect(
        NotificationService.remainderDateTime(due, time, 'hours', 2),
        DateTime(2025, 3, 10, 12, 30),
      );
    });

    test('days', () {
      expect(
        NotificationService.remainderDateTime(due, time, 'days', 1),
        DateTime(2025, 3, 9, 14, 30),
      );
    });

    test('weeks', () {
      expect(
        NotificationService.remainderDateTime(due, time, 'weeks', 2),
        DateTime(2025, 2, 24, 14, 30),
      );
    });

    test('crossing midnight moves to the previous day', () {
      expect(
        NotificationService.remainderDateTime(
          due,
          DateTime(1970, 1, 1, 0, 10),
          'minutes',
          30,
        ),
        DateTime(2025, 3, 9, 23, 40),
      );
    });

    test('"none" and unknown types return the due moment unchanged', () {
      expect(
        NotificationService.remainderDateTime(due, time, 'none', 5),
        DateTime(2025, 3, 10, 14, 30),
      );
      expect(
        NotificationService.remainderDateTime(due, time, 'fortnights', 5),
        DateTime(2025, 3, 10, 14, 30),
      );
    });

    test('zero amount returns the due moment', () {
      expect(
        NotificationService.remainderDateTime(due, time, 'hours', 0),
        DateTime(2025, 3, 10, 14, 30),
      );
    });
  });
}
