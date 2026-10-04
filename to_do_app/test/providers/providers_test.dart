import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/providers/data_provider.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/file_sort_provider.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/themes/dark_mode.dart';
import 'package:to_do_app/themes/light_mode.dart';
import 'package:to_do_app/themes/theme_provider.dart';

import '../helpers/test_data.dart';

void main() {
  group('simple state providers', () {
    test('GroupingProvider defaults to Default and notifies', () {
      final p = GroupingProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.mode, GroupingMode.Default);
      p.setMode(GroupingMode.month);
      expect(p.mode, GroupingMode.month);
      expect(calls, 1);
    });

    test('SortingProvider defaults to newest-created first', () {
      final p = SortingProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.mode, SortingMode.createdDateDecreasing);
      p.setMode(SortingMode.aToz);
      expect(p.mode, SortingMode.aToz);
      expect(p.doSort, isTrue);
      expect(calls, 1);
    });

    test('SearchingProvider stores the query', () {
      final p = SearchingProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.query, '');
      p.setQuery('milk');
      expect(p.query, 'milk');
      expect(calls, 1);
    });

    test('ViewProvider starts in tile view', () {
      final p = ViewProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.currentView, 'tileView');
      p.setView('listView');
      expect(p.currentView, 'listView');
      expect(calls, 1);
    });

    test('FileSearchProvider stores the query', () {
      final p = FileSearchProvider();
      var calls = 0;
      p.addListener(() => calls++);
      p.setSearchQuery('report');
      expect(p.searchQuery, 'report');
      expect(calls, 1);
    });

    test('FileSortProvider defaults to newest first', () {
      final p = FileSortProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.sortingMode, SortingMode.createdDateDecreasing);
      p.setSortingMode(SortingMode.zToa);
      expect(p.sortingMode, SortingMode.zToa);
      expect(calls, 1);
    });
  });

  group('ThemeProvider', () {
    test('starts light and toggles to dark and back', () {
      final p = ThemeProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.themeData, lightMode);
      expect(p.isDarkMode, isFalse);
      p.toggleTheme();
      expect(p.themeData, darkMode);
      expect(p.isDarkMode, isTrue);
      p.toggleTheme();
      expect(p.isDarkMode, isFalse);
      expect(calls, 2);
    });

    test('themeData setter notifies', () {
      final p = ThemeProvider();
      var calls = 0;
      p.addListener(() => calls++);
      p.themeData = darkMode;
      expect(p.isDarkMode, isTrue);
      expect(calls, 1);
    });
  });

  group('CalendarSyncProvider', () {
    test('startSync / updateProgress / finishSync lifecycle', () {
      final p = CalendarSyncProvider();
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.isSyncing, isFalse);
      expect(p.lastSyncedAt, isNull);

      p.startSync();
      expect(p.isSyncing, isTrue);
      expect(p.progress, 0);

      p.updateProgress(0.5);
      expect(p.progress, 0.5);

      final before = DateTime.now();
      p.finishSync();
      expect(p.isSyncing, isFalse);
      expect(p.progress, 1.0);
      expect(p.lastSyncedAt!.isBefore(before), isFalse);
      expect(calls, 3);
    });

    test('dismiss hides progress without recording a sync time', () {
      final p = CalendarSyncProvider()..startSync();
      p.dismiss();
      expect(p.isSyncing, isFalse);
      expect(p.lastSyncedAt, isNull);
    });

    test('startSync resets progress from an earlier run', () {
      final p = CalendarSyncProvider()..updateProgress(0.9);
      p.startSync();
      expect(p.progress, 0);
    });

    test('notify() just notifies', () {
      final p = CalendarSyncProvider();
      var calls = 0;
      p.addListener(() => calls++);
      p.notify();
      expect(calls, 1);
    });
  });

  group('AuthProvider', () {
    test('defaults to signed out', () {
      final p = AuthProvider();
      expect(p.isGoogleSignedIn, isFalse);
      expect(p.isOutlookSignedIn, isFalse);
      expect(p.displayName, '');
      expect(p.email, '');
      expect(p.photoUrl, '');
    });

    test('constructor restores a prior session', () {
      final p = AuthProvider(
        isGoogleSignedIn: true,
        displayName: 'Ada',
        email: 'ada@example.com',
        photoUrl: 'http://img',
      );
      expect(p.isGoogleSignedIn, isTrue);
      expect(p.displayName, 'Ada');
    });

    test('setGoogleSignedIn(true) stores the profile and notifies', () {
      final p = AuthProvider();
      var calls = 0;
      p.addListener(() => calls++);
      p.setGoogleSignedIn(
        true,
        displayName: 'Ada',
        email: 'ada@example.com',
        photoUrl: 'http://img',
      );
      expect(p.isGoogleSignedIn, isTrue);
      expect(p.email, 'ada@example.com');
      expect(p.photoUrl, 'http://img');
      expect(calls, 1);
    });

    test('setGoogleSignedIn(false) signs out and clears the profile', () {
      final p = AuthProvider(
        isGoogleSignedIn: true,
        displayName: 'Ada',
        email: 'a@b.c',
      );
      p.setGoogleSignedIn(false);
      expect(p.isGoogleSignedIn, isFalse);
      expect(p.displayName, '');
      expect(p.email, '');
    });

    test('Outlook sign in / out', () {
      final p = AuthProvider();
      var calls = 0;
      p.addListener(() => calls++);
      p.setOutlookSignedIn(true);
      expect(p.isOutlookSignedIn, isTrue);
      p.signOutOutlook();
      expect(p.isOutlookSignedIn, isFalse);
      expect(calls, 2);
    });

    test('signing out of Outlook leaves Google alone', () {
      final p = AuthProvider(isGoogleSignedIn: true, isOutlookSignedIn: true);
      p.signOutOutlook();
      expect(p.isGoogleSignedIn, isTrue);
    });
  });

  group('DataProvider', () {
    late TestDb env;
    late DataProvider provider;

    setUp(() async {
      env = await TestDb.open();
      provider = DataProvider(env.db);
    });
    tearDown(() async => env.dispose());

    test('getters expose the same list objects as the database', () {
      expect(identical(provider.tasks, env.db.toDoList), isTrue);
      expect(identical(provider.localEvents, env.db.localCalTasks), isTrue);
      expect(identical(provider.googleEvents, env.db.googleCalTasks), isTrue);
      expect(identical(provider.outlookEvents, env.db.outlookCalTasks), isTrue);
      expect(identical(provider.categories, env.db.categories), isTrue);
    });

    test('addTask appends, persists and notifies', () async {
      var calls = 0;
      provider.addListener(() => calls++);
      await provider.addTask(makeTask('new'));
      expect(provider.tasks.single.name, 'new');
      expect(calls, 1);
      env.db.loadToDoList();
      expect(env.db.toDoList.single.name, 'new');
    });

    test('deleteTaskAt removes and persists', () async {
      await provider.addTask(makeTask('a'));
      await provider.addTask(makeTask('b'));
      await provider.deleteTaskAt(0);
      expect(provider.tasks.map((t) => t.name), ['b']);
      env.db.loadToDoList();
      expect(env.db.toDoList.map((t) => t.name), ['b']);
    });

    test('reorderTasks moves a task and persists the order', () async {
      await provider.addTask(makeTask('a'));
      await provider.addTask(makeTask('b'));
      await provider.addTask(makeTask('c'));
      await provider.reorderTasks(0, 2);
      expect(provider.tasks.map((t) => t.name), ['b', 'c', 'a']);
      env.db.loadToDoList();
      expect(env.db.toDoList.map((t) => t.name), ['b', 'c', 'a']);
    });

    test('persistCategories notifies', () async {
      var calls = 0;
      provider.addListener(() => calls++);
      env.db.categories = ['None', 'X'];
      await provider.persistCategories();
      expect(calls, 1);
      env.db.loadCategories();
      expect(env.db.categories, ['None', 'X']);
    });

    test('persistAll writes every box and notifies', () async {
      var calls = 0;
      provider.addListener(() => calls++);
      env.db.googleCalTasks.add(makeEvent('g'));
      env.db.toDoList.add(makeTask('t'));
      await provider.persistAll();
      expect(calls, 1);
      env.db.loadGoogleCalTasks();
      expect(env.db.googleCalTasks.single.name, 'g');
    });
  });
}
