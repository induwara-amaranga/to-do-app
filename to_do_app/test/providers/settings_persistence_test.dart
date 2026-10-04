import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/providers/file_sort_provider.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/settings_providers.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/themes/theme_provider.dart';

import '../helpers/test_data.dart';

const teal = Color(0xFF0F766E);

/// Builds the app's real settings-backed providers around [db] and returns
/// one of each, the way the app does at launch.
class Launch {
  final ThemeProvider theme;
  final GroupingProvider grouping;
  final SortingProvider sorting;
  final FileSortProvider fileSort;
  final ViewProvider view;
  Launch._(this.theme, this.grouping, this.sorting, this.fileSort, this.view);

  static Future<Launch> start(WidgetTester? t, ToDoDataBase db) async {
    late Launch launch;
    final tree = MultiProvider(
      providers: settingsBackedProviders(db),
      child: Builder(
        builder: (context) {
          launch = Launch._(
            context.read<ThemeProvider>(),
            context.read<GroupingProvider>(),
            context.read<SortingProvider>(),
            context.read<FileSortProvider>(),
            context.read<ViewProvider>(),
          );
          return const SizedBox();
        },
      ),
    );
    await t!.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: tree),
    );
    return launch;
  }
}

/// In-memory stand-in for the on-disk settings: records each save.
class _MemoryDb extends ToDoDataBase {
  int saves = 0;
  @override
  void saveSettings() => saves++;
}

void main() {
  setUpAll(initTestTimeZone);

  group('first launch uses the defaults', () {
    testWidgets('light mode, amber, newest first, default grouping', (t) async {
      final l = await Launch.start(t, _MemoryDb());
      expect(l.theme.isDarkMode, isFalse);
      expect(l.theme.accent, kAccent);
      expect(l.sorting.mode, SortingMode.createdDateDecreasing);
      expect(l.grouping.mode, GroupingMode.Default);
      expect(l.fileSort.sortingMode, SortingMode.createdDateDecreasing);
      expect(l.view.currentView, 'tileView');
    });

    testWidgets('building the providers does not write anything', (t) async {
      final db = _MemoryDb();
      await Launch.start(t, db);
      expect(db.saves, 0);
    });
  });

  group('changes are written to the settings', () {
    testWidgets('dark mode', (t) async {
      final db = _MemoryDb();
      final l = await Launch.start(t, db);
      l.theme.toggleTheme();
      expect(db.settings.darkMode, isTrue);
      expect(db.saves, 1);
      l.theme.toggleTheme();
      expect(db.settings.darkMode, isFalse);
    });

    testWidgets('accent colour', (t) async {
      final db = _MemoryDb();
      final l = await Launch.start(t, db);
      l.theme.setAccent(teal);
      expect(db.settings.accentColor, teal.toARGB32());
    });

    testWidgets('changing the accent does not lose the dark setting', (
      t,
    ) async {
      final db = _MemoryDb();
      final l = await Launch.start(t, db);
      l.theme.toggleTheme();
      l.theme.setAccent(teal);
      expect(db.settings.darkMode, isTrue);
      expect(db.settings.accentColor, teal.toARGB32());
    });

    testWidgets('task sort, grouping, timetable view and sort', (t) async {
      final db = _MemoryDb();
      final l = await Launch.start(t, db);
      l.sorting.setMode(SortingMode.dueDateIncreasing);
      l.grouping.setMode(GroupingMode.month);
      l.view.setView('listView');
      l.fileSort.setSortingMode(SortingMode.aToz);
      expect(db.settings.taskSortMode, 'dueDateIncreasing');
      expect(db.settings.taskGroupMode, 'month');
      expect(db.settings.timetableView, 'listView');
      expect(db.settings.timetableSortMode, 'aToz');
      expect(db.saves, 4);
    });

    testWidgets('a change leaves every other setting untouched', (t) async {
      final db =
          _MemoryDb()
            ..settings = const AppSettings(
              widgetTaskCount: 9,
              timeFormat: '24 hour',
              morningPlan: true,
            );
      final l = await Launch.start(t, db);
      l.theme.toggleTheme();
      l.sorting.setMode(SortingMode.aToz);
      expect(db.settings.widgetTaskCount, 9);
      expect(db.settings.timeFormat, '24 hour');
      expect(db.settings.morningPlan, isTrue);
    });
  });

  group('a restart restores the choices', () {
    testWidgets('every preference comes back', (t) async {
      final db = _MemoryDb();
      var l = await Launch.start(t, db);
      l.theme.toggleTheme();
      l.theme.setAccent(teal);
      l.sorting.setMode(SortingMode.zToa);
      l.grouping.setMode(GroupingMode.year);
      l.view.setView('listView');
      l.fileSort.setSortingMode(SortingMode.createdDateIncreasing);

      // "Restart": new providers built from whatever was saved.
      await t.pumpWidget(const SizedBox());
      l = await Launch.start(t, db);

      expect(l.theme.isDarkMode, isTrue);
      expect(l.theme.accent, teal);
      expect(l.sorting.mode, SortingMode.zToa);
      expect(l.grouping.mode, GroupingMode.year);
      expect(l.view.currentView, 'listView');
      expect(l.fileSort.sortingMode, SortingMode.createdDateIncreasing);
    });

    testWidgets('dark mode keeps its custom accent after a restart', (t) async {
      final db = _MemoryDb();
      var l = await Launch.start(t, db);
      l.theme.setAccent(teal);
      l.theme.toggleTheme();
      await t.pumpWidget(const SizedBox());
      l = await Launch.start(t, db);
      expect(l.theme.isDarkMode, isTrue);
      expect(l.theme.themeData.extension<AppColors>()!.accent, teal);
    });

    testWidgets('unknown saved names fall back to the defaults', (t) async {
      final db =
          _MemoryDb()
            ..settings = const AppSettings(
              taskSortMode: 'from-a-newer-version',
              taskGroupMode: 'nonsense',
              timetableSortMode: '???',
            );
      final l = await Launch.start(t, db);
      expect(l.sorting.mode, SortingMode.createdDateDecreasing);
      expect(l.grouping.mode, GroupingMode.Default);
      expect(l.fileSort.sortingMode, SortingMode.createdDateDecreasing);
    });

    testWidgets('settings saved by an older version still load', (t) async {
      final old =
          const AppSettings().toMap()
            ..remove('darkMode')
            ..remove('taskSortMode')
            ..remove('taskGroupMode')
            ..remove('timetableView')
            ..remove('timetableSortMode');
      final db = _MemoryDb()..settings = AppSettings.fromMap(old);
      final l = await Launch.start(t, db);
      expect(l.theme.isDarkMode, isFalse);
      expect(l.sorting.mode, SortingMode.createdDateDecreasing);
      expect(l.view.currentView, 'tileView');
    });
  });

  group('enum names', () {
    test('every sort mode round-trips through its name', () {
      for (final m in SortingMode.values) {
        expect(sortingModeFromName(m.name), m);
      }
    });

    test('every grouping mode round-trips through its name', () {
      for (final m in GroupingMode.values) {
        expect(groupingModeFromName(m.name), m);
      }
    });

    test('null and unknown names use the fallback', () {
      expect(sortingModeFromName(null), SortingMode.createdDateDecreasing);
      expect(
        sortingModeFromName('x', fallback: SortingMode.aToz),
        SortingMode.aToz,
      );
      expect(groupingModeFromName(null), GroupingMode.Default);
    });
  });

  group('settings survive on disk', () {
    test('all preferences are restored from the Hive box', () async {
      final env = await TestDb.open();
      addTearDown(env.dispose);
      env.db.settings = const AppSettings(
        darkMode: true,
        accentColor: 0xFF0F766E,
        taskSortMode: 'aToz',
        taskGroupMode: 'day',
        timetableView: 'listView',
        timetableSortMode: 'zToa',
        widgetTaskCount: 8,
        timeFormat: '24 hour',
      );
      env.db.saveSettings();
      env.db.runMigrations();
      await Hive.box('meta').flush();

      await Hive.close();
      Hive.init(env.dir.path);
      final fresh = ToDoDataBase();
      await fresh.openBoxes();
      fresh.loadData();

      final s = fresh.settings;
      expect(s.darkMode, isTrue);
      expect(s.accentColor, 0xFF0F766E);
      expect(s.taskSortMode, 'aToz');
      expect(s.taskGroupMode, 'day');
      expect(s.timetableView, 'listView');
      expect(s.timetableSortMode, 'zToa');
      expect(s.widgetTaskCount, 8);
      expect(s.timeFormat, '24 hour');
    });
  });
}
