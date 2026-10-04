import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/pages/settings_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/providers/data_provider.dart';
import 'package:to_do_app/themes/light_mode.dart';
import 'package:to_do_app/themes/theme_provider.dart';

import '../helpers/test_data.dart';

/// In-memory stand-in for the database: records settings saves and removals
/// without touching Hive (disk I/O does not complete in the widget-test zone).
class _MemoryDb extends ToDoDataBase {
  int settingsSaves = 0;

  @override
  void saveSettings() => settingsSaves++;

  @override
  Future<void> removeTasks(Iterable<Task> doomed) async {
    final set = Set<Task>.identity()..addAll(doomed);
    toDoList.removeWhere(set.contains);
  }
}

String day(int daysFromToday) => utcDay(daysFromToday);

/// [count] past tasks, all well outside the safety margin.
List<Task> pastTasks(int count) => [
  for (var i = 0; i < count; i++) makeTask('p$i', dueDate: day(-10 - i)),
];

Future<_MemoryDb> pumpSettings(
  WidgetTester t, {
  List<Task> tasks = const [],
  int keep = 0,
}) async {
  final db =
      _MemoryDb()
        ..createInitialData()
        ..toDoList = [...tasks]
        ..settings = AppSettings(keepLatestPastTasks: keep);
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider(db)),
      ],
      child: MaterialApp(theme: lightMode, home: SettingsPage(db: db)),
    ),
  );
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.text('Remove Past Tasks'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  return db;
}

Future<void> openPicker(WidgetTester t) async {
  await t.tap(find.text('Remove Past Tasks'));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(initTestTimeZone);

  testWidgets('the row is in Preferences and shows Never by default', (
    t,
  ) async {
    await pumpSettings(t);
    expect(
      find.text('Older past tasks are deleted automatically'),
      findsOneWidget,
    );
    expect(find.text('Remove Past Tasks'), findsOneWidget);
    expect(find.text('Never'), findsOneWidget);
  });

  testWidgets('the picker offers exactly the four choices', (t) async {
    await pumpSettings(t);
    await openPicker(t);
    expect(find.text('Never remove'), findsOneWidget);
    expect(find.text('Keep latest 500 tasks'), findsOneWidget);
    expect(find.text('Keep latest 1000 tasks'), findsOneWidget);
    expect(find.text('Keep latest 2000 tasks'), findsOneWidget);
  });

  testWidgets('the saved choice shows in the row', (t) async {
    await pumpSettings(t, keep: 1000);
    expect(find.text('Latest 1000'), findsOneWidget);
    expect(find.text('Never'), findsNothing);
  });

  testWidgets('choosing a limit with nothing to remove just saves it', (
    t,
  ) async {
    final db = await pumpSettings(t, tasks: pastTasks(20));
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'nothing to confirm',
    );
    expect(db.settings.keepLatestPastTasks, 500);
    expect(db.settingsSaves, 1);
    expect(db.toDoList.length, 20);
    expect(find.text('Latest 500'), findsOneWidget);
  });

  testWidgets('a limit that deletes tasks asks first and says how many', (
    t,
  ) async {
    final db = await pumpSettings(t, tasks: pastTasks(600));
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();

    expect(find.text('Remove 100 past tasks?'), findsOneWidget);
    expect(db.toDoList.length, 600, reason: 'nothing deleted before confirm');
    expect(db.settings.keepLatestPastTasks, 0);
  });

  testWidgets('cancelling keeps every task and leaves the setting alone', (
    t,
  ) async {
    final db = await pumpSettings(t, tasks: pastTasks(600));
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    expect(db.toDoList.length, 600);
    expect(db.settings.keepLatestPastTasks, 0);
    expect(db.settingsSaves, 0);
    expect(find.text('Never'), findsOneWidget);
  });

  testWidgets('confirming removes the oldest tasks and saves the choice', (
    t,
  ) async {
    final db = await pumpSettings(t, tasks: pastTasks(600));
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();

    expect(db.toDoList.length, 500);
    expect(db.settings.keepLatestPastTasks, 500);
    expect(db.settingsSaves, 1);
    // p0 is the newest; p599..p500 were the oldest hundred.
    expect(db.toDoList.any((x) => x.name == 'p0'), isTrue);
    expect(db.toDoList.any((x) => x.name == 'p599'), isFalse);
    expect(find.text('Removed 100 past tasks'), findsOneWidget);
    expect(find.text('Latest 500'), findsOneWidget);
  });

  testWidgets('a single task is described in the singular', (t) async {
    final db = await pumpSettings(t, tasks: pastTasks(501));
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();
    expect(find.text('Remove 1 past task?'), findsOneWidget);
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(find.text('Removed 1 past task'), findsOneWidget);
    expect(db.toDoList.length, 500);
  });

  testWidgets('upcoming and undated tasks survive a cleanup', (t) async {
    final db = await pumpSettings(
      t,
      tasks: [
        ...pastTasks(510),
        makeTask('upcoming', dueDate: day(30)),
        makeTask('undated', dueDate: null),
      ],
    );
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(db.toDoList.any((x) => x.name == 'upcoming'), isTrue);
    expect(db.toDoList.any((x) => x.name == 'undated'), isTrue);
    expect(db.toDoList.length, 502);
  });

  testWidgets('switching back to Never keeps everything', (t) async {
    final db = await pumpSettings(t, tasks: pastTasks(30), keep: 500);
    await openPicker(t);
    await t.tap(find.text('Never remove'));
    await t.pumpAndSettle();
    expect(db.settings.keepLatestPastTasks, 0);
    expect(db.toDoList.length, 30);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('picking the option already in use does nothing', (t) async {
    final db = await pumpSettings(t, tasks: pastTasks(5), keep: 500);
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();
    expect(db.settingsSaves, 0);
  });

  testWidgets('the task list is told to refresh after a cleanup', (t) async {
    final db = await pumpSettings(t, tasks: pastTasks(600));
    final data = Provider.of<DataProvider>(
      t.element(find.byType(SettingsPage)),
      listen: false,
    );
    final before = data.taskRevision;
    await openPicker(t);
    await t.tap(find.text('Keep latest 500 tasks'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(data.taskRevision, greaterThan(before));
    expect(db.toDoList.length, 500);
  });
}
