import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/services/filter_tasks_service.dart';

import '../helpers/test_data.dart';

List<String> names(Iterable<dynamic> tasks) =>
    tasks.map<String>((t) => t.name as String).toList();

void main() {
  setUpAll(initTestTimeZone);

  Map<String, dynamic> filter({
    List<String> categories = const [],
    List<DateTime> dates = const [],
    String selected = 'Selected_dates',
  }) => {
    'categories': categories,
    'selectedDueDates': dates,
    'selectedFilter': selected,
  };

  final work = makeTask(
    'work-low',
    category: 'Work',
    priority: 'Low',
    dueDate: utcDay(5),
  );
  final home = makeTask(
    'home-high',
    category: 'Home',
    priority: 'High',
    dueDate: utcDay(5),
  );
  final done = makeTask(
    'done',
    category: 'Home',
    priority: 'Medium',
    completed: true,
    dueDate: utcDay(-5),
  );
  final overdue = makeTask(
    'overdue',
    category: 'Misc',
    priority: 'Medium',
    dueDate: utcDay(-5),
  );
  final upcoming = makeTask(
    'upcoming',
    category: 'Misc',
    priority: 'Medium',
    dueDate: utcDay(5),
  );
  final all = [work, home, done, overdue, upcoming];

  group('FilterTasksService.filterTasksByCategory (no date filter)', () {
    test('no categories selected keeps every task', () {
      final r = FilterTasksService.filterTasksByCategory(all, filter());
      expect(r.length, all.length);
    });

    test('filters by category', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['Work']),
      );
      expect(names(r), ['work-low']);
    });

    test('a priority name also matches', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['High']),
      );
      expect(names(r), ['home-high']);
    });

    test('several categories are OR-ed', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['Work', 'Home']),
      );
      expect(names(r), ['work-low', 'home-high', 'done']);
    });

    test('Completed keeps completed tasks', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['Completed']),
      );
      expect(names(r), ['done']);
    });

    test('Pending keeps unfinished tasks due in the future', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['Pending']),
      );
      expect(names(r), ['work-low', 'home-high', 'upcoming']);
    });

    test('Missed keeps unfinished tasks whose due date has passed', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['Missed']),
      );
      expect(names(r), ['overdue']);
    });

    test('unknown category matches nothing', () {
      final r = FilterTasksService.filterTasksByCategory(
        all,
        filter(categories: ['Nope']),
      );
      expect(r, isEmpty);
    });

    test('empty list in, empty list out', () {
      expect(
        FilterTasksService.filterTasksByCategory([], filter(categories: ['x'])),
        isEmpty,
      );
    });
  });

  group('FilterTasksService.filterTasksByCategory (date filter)', () {
    final fixed = [
      makeTask('mar3', dueDate: '2025-03-03', category: 'A'),
      makeTask('mar4', dueDate: '2025-03-04', category: 'A'),
      makeTask('mar5', dueDate: '2025-03-05', category: 'B'),
    ];

    test('Selected_dates keeps tasks on that day', () {
      final r = FilterTasksService.filterTasksByCategory(
        fixed,
        filter(dates: [DateTime.utc(2025, 3, 4)]),
      );
      expect(names(r), ['mar4']);
    });

    test('Selected_dates also applies the category filter', () {
      final onDay = FilterTasksService.filterTasksByCategory(
        fixed,
        filter(dates: [DateTime.utc(2025, 3, 4)], categories: ['B']),
      );
      expect(onDay, isEmpty);
      final match = FilterTasksService.filterTasksByCategory(
        fixed,
        filter(dates: [DateTime.utc(2025, 3, 5)], categories: ['B']),
      );
      expect(names(match), ['mar5']);
    });

    test('Before keeps tasks earlier than the date', () {
      final r = FilterTasksService.filterTasksByCategory(
        fixed,
        filter(dates: [DateTime.utc(2025, 3, 5)], selected: 'Before'),
      );
      expect(names(r), ['mar3', 'mar4']);
    });

    test('After keeps tasks later than the start of that date', () {
      // The comparison is against midnight, so the selected day itself is
      // included (unlike Before, which excludes it).
      final r = FilterTasksService.filterTasksByCategory(
        fixed,
        filter(dates: [DateTime.utc(2025, 3, 4)], selected: 'After'),
      );
      expect(names(r), ['mar4', 'mar5']);
    });

    test('tasks without a due date never match a date filter', () {
      final r = FilterTasksService.filterTasksByCategory(
        [makeTask('undated', dueDate: null)],
        filter(dates: [DateTime.utc(2025, 3, 4)]),
      );
      expect(r, isEmpty);
    });
  });
}
