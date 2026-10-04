import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/pages/task_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
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
}) async {
  final search = SearchingProvider();
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GroupingProvider()..setMode(grouping),
        ),
        ChangeNotifierProvider(create: (_) => SortingProvider()),
        ChangeNotifierProvider.value(value: search),
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
  await t.pumpAndSettle();
  return search;
}

ToDoDataBase newDb() {
  final db = ToDoDataBase();
  db.createInitialData();
  return db;
}

void main() {
  setUpAll(initTestTimeZone);

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
            makeTask('Buy milk', dueDate: utcDay(0)),
            makeTask('Call mum', dueDate: utcDay(0)),
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
            makeTask('Open task', dueDate: utcDay(0)),
            makeTask('Finished task', dueDate: utcDay(0), completed: true),
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
    final db =
        newDb()
          ..hidingCategories = ['Study'];
    await pumpTaskPage(t, db);
    expect(find.text('Study'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('the search query filters the visible tasks', (t) async {
    final db =
        newDb()
          ..toDoList = [
            makeTask('Buy milk', dueDate: utcDay(0)),
            makeTask('Call mum', dueDate: utcDay(0)),
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
    final db = newDb()..toDoList = [makeTask('Buy milk', dueDate: utcDay(0))];
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
            makeTask('Work item', category: 'Work', dueDate: utcDay(0)),
            makeTask('Study item', category: 'Study', dueDate: utcDay(0)),
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
