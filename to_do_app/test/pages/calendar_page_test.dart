import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/components/task_tile.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/pages/calendar_page.dart';
import 'package:to_do_app/themes/light_mode.dart';

import '../helpers/test_data.dart';

String monthTitle(DateTime d) => DateFormat.yMMMM().format(d);

DateTime nextMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 1, 1);
}

Future<void> pumpCalendar(
  WidgetTester t, {
  List<dynamic> tasks = const [],
}) async {
  final db =
      ToDoDataBase()
        ..createInitialData()
        ..toDoList = [for (final x in tasks) x];
  await t.pumpWidget(MaterialApp(theme: lightMode, home: CalendarPage(db: db)));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(initTestTimeZone);
  tickTests();
  indexAndListTests();

  testWidgets('opens on the current month', (t) async {
    await pumpCalendar(t);
    expect(find.text(monthTitle(DateTime.now())), findsOneWidget);
  });

  testWidgets('the next-month arrow moves the calendar forward', (t) async {
    await pumpCalendar(t);
    await t.tap(find.byIcon(Icons.chevron_right).first);
    await t.pumpAndSettle();
    expect(find.text(monthTitle(nextMonth())), findsOneWidget);
  });

  group('the month being viewed is kept when the page rebuilds', () {
    testWidgets('switching between month and week view', (t) async {
      await pumpCalendar(t);
      await t.tap(find.byIcon(Icons.chevron_right).first);
      await t.pumpAndSettle();
      expect(find.text(monthTitle(nextMonth())), findsOneWidget);

      // The format button rebuilds the page (setState in onFormatChanged).
      await t.tap(find.text('Week'));
      await t.pumpAndSettle();

      expect(
        find.text(monthTitle(nextMonth())),
        findsOneWidget,
        reason: 'must not jump back to the current month',
      );
      expect(find.text(monthTitle(DateTime.now())), findsNothing);
    });

    testWidgets('picking a day in another month', (t) async {
      await pumpCalendar(t);
      await t.tap(find.byIcon(Icons.chevron_right).first);
      await t.pumpAndSettle();
      await t.tap(find.text('15').first);
      await t.pumpAndSettle();
      expect(find.text(monthTitle(nextMonth())), findsOneWidget);
    });

    testWidgets('several months ahead and back again', (t) async {
      await pumpCalendar(t);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byIcon(Icons.chevron_right).first);
        await t.pumpAndSettle();
      }
      final now = DateTime.now();
      final target = DateTime(now.year, now.month + 3, 1);
      expect(find.text(monthTitle(target)), findsOneWidget);

      await t.tap(find.text('Week'));
      await t.pumpAndSettle();
      expect(find.text(monthTitle(target)), findsOneWidget);

      await t.tap(find.byIcon(Icons.chevron_left).first);
      await t.pumpAndSettle();
      expect(
        find.text(monthTitle(DateTime(now.year, now.month + 2, 1))),
        findsOneWidget,
        reason: 'going back is relative to where the user is, not today',
      );
    });
  });
}

/// Counts how the page saves, without touching Hive.
class _CountingDb extends ToDoDataBase {
  final List<int> savedIndexes = [];
  int fullSaves = 0;

  @override
  Future<void> saveTaskAt(int index) async => savedIndexes.add(index);

  @override
  Future<void> updateDataBase() async => fullSaves++;

  @override
  Future<void> saveToDoList() async => fullSaves++;
}

/// A task shown on the Calendar page's initially selected day (today).
Task todayTask(String name) =>
    makeTask(name, dueDate: localDay(0), dueTime: '06:00');

Future<_CountingDb> pumpCalendarWith(WidgetTester t, List<Task> tasks) async {
  final db =
      _CountingDb()
        ..createInitialData()
        ..toDoList = tasks
        ..settings = const AppSettings(
          completionTone: false,
          completionAnimation: false,
        );
  await t.pumpWidget(MaterialApp(theme: lightMode, home: CalendarPage(db: db)));
  await t.pumpAndSettle();
  return db;
}

dynamic calState(WidgetTester t) => t.state(find.byType(CalendarPage));

void indexAndListTests() {
  group('day index cache', () {
    testWidgets('is built once and reused across rebuilds', (t) async {
      await pumpCalendarWith(t, [todayTask('A')]);
      expect(calState(t).debugIndexBuilds, 1);

      // Day taps and view switches call setState; the data did not change.
      await t.tap(find.text('15').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Week'));
      await t.pumpAndSettle();
      await t.tap(find.text('Month'));
      await t.pumpAndSettle();
      expect(calState(t).debugIndexBuilds, 1);
    });

    testWidgets('is rebuilt when the data changes', (t) async {
      final db = await pumpCalendarWith(t, [todayTask('A')]);
      expect(calState(t).debugIndexBuilds, 1);

      db.dataRevision++; // what any save does
      await t.tap(find.text('15').first);
      await t.pumpAndSettle();
      expect(calState(t).debugIndexBuilds, 2);

      await t.tap(find.text('16').first);
      await t.pumpAndSettle();
      expect(calState(t).debugIndexBuilds, 2, reason: 'and then reused again');
    });

    testWidgets('is rebuilt when the time zone changes', (t) async {
      await pumpCalendarWith(t, [todayTask('A')]);
      expect(calState(t).debugIndexBuilds, 1);
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      await t.tap(find.text('15').first);
      await t.pumpAndSettle();
      expect(calState(t).debugIndexBuilds, 2);
      tz.setLocalLocation(tz.getLocation('Asia/Colombo')); // restore
    });
  });

  group('day list is lazy', () {
    testWidgets('builds only the visible tiles of a busy day', (t) async {
      await pumpCalendarWith(t, [
        for (var i = 0; i < 80; i++) todayTask('Task $i'),
      ]);
      final built = find.byType(TaskTile).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(30), reason: 'not all 80 tiles built up front');
    });

    testWidgets('scrolling brings later tasks into view', (t) async {
      await pumpCalendarWith(t, [
        for (var i = 0; i < 80; i++) todayTask('Task $i'),
      ]);
      expect(find.text('Task 79'), findsNothing);
      await t.dragUntilVisible(
        find.text('Task 79'),
        find.byType(ListView).last,
        const Offset(0, -300),
      );
      expect(find.text('Task 79'), findsOneWidget);
    });

    testWidgets('a quiet day shows no list rows', (t) async {
      await pumpCalendarWith(t, []);
      expect(find.byType(TaskTile), findsNothing);
      expect(find.text('Tasks'), findsOneWidget); // only the bottom-nav label
    });

    testWidgets('the Tasks heading precedes the tiles', (t) async {
      await pumpCalendarWith(t, [todayTask('One')]);
      final heading = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Tasks'),
      );
      expect(heading, findsOneWidget);
      expect(
        t.getTopLeft(heading).dy,
        lessThan(t.getTopLeft(find.text('One')).dy),
      );
    });
  });
}

void tickTests() {
  group('ticking a task on the Calendar page', () {
    Future<void> tick(WidgetTester t) async {
      await t.tap(find.byType(Checkbox).first);
      await t.pump(const Duration(milliseconds: 1100));
      await t.pumpAndSettle();
    }

    testWidgets('saves only that task, not every box', (t) async {
      final db = await pumpCalendarWith(t, [
        makeTask('Other', dueDate: localDay(5)),
        todayTask('Today task'),
      ]);
      expect(find.text('Today task'), findsOneWidget);

      await tick(t);

      expect(db.savedIndexes, [1], reason: 'only the ticked task, by index');
      expect(db.fullSaves, 0, reason: 'no full rewrite of the boxes');
    });

    testWidgets('marks it completed with a completion time', (t) async {
      final db = await pumpCalendarWith(t, [todayTask('Today task')]);
      await tick(t);
      final task = db.toDoList.single;
      expect(task.completed, isTrue);
      expect(task.completedAt, isNot('none'));
    });

    testWidgets('unticking clears the completion time', (t) async {
      final done =
          todayTask('Done task')
            ..completed = true
            ..completedAt = DateTime.now().toUtc().toString();
      final db = await pumpCalendarWith(t, [done]);
      await tick(t);
      expect(db.toDoList.single.completed, isFalse);
      expect(db.toDoList.single.completedAt, 'none');
      expect(db.savedIndexes, [0]);
      expect(db.fullSaves, 0);
    });

    testWidgets('each tick is its own single save', (t) async {
      final db = await pumpCalendarWith(t, [
        todayTask('First'),
        todayTask('Second'),
      ]);
      await tick(t);
      await tick(t);
      expect(db.savedIndexes.length, 2);
      expect(db.fullSaves, 0);
    });
  });
}
