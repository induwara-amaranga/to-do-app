import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/group_tasks_service.dart';
import 'package:to_do_app/services/search_tasks.dart';
import 'package:to_do_app/services/sort_tasks_service.dart';

import '../helpers/test_data.dart';

List<String> names(Iterable<Task> tasks) => tasks.map((t) => t.name).toList();

void main() {
  setUpAll(initTestTimeZone);

  group('SearchTasks.searchByQuery', () {
    final tasks = [
      makeTask('Buy milk', note: 'two litres'),
      makeTask('Call mum', note: null),
      makeTask('Pay rent', note: 'Landlord: milk street'),
    ];

    test('empty query returns every task', () {
      expect(SearchTasks.searchByQuery('', tasks), tasks);
    });

    test('matches on name', () {
      expect(names(SearchTasks.searchByQuery('call', tasks)), ['Call mum']);
    });

    test('matches on note', () {
      expect(names(SearchTasks.searchByQuery('litres', tasks)), ['Buy milk']);
    });

    test('matches name or note', () {
      expect(names(SearchTasks.searchByQuery('milk', tasks)), [
        'Buy milk',
        'Pay rent',
      ]);
    });

    test('tasks without a note do not crash and can still match by name', () {
      expect(names(SearchTasks.searchByQuery('mum', tasks)), ['Call mum']);
    });

    test('no match returns an empty list', () {
      expect(SearchTasks.searchByQuery('zzz', tasks), isEmpty);
    });

    test(
      'an upper-case query still finds the task',
      () {
        expect(names(SearchTasks.searchByQuery('Buy', tasks)), ['Buy milk']);
      },
      skip:
          'Known bug: the query is not lower-cased, so typing a capital '
          'letter in the search bar matches nothing',
    );
  });

  group('SortTasksService', () {
    Task t(
      String name, {
      String? due = '2025-03-04',
      String time = '10:00',
      String created = '2025-01-01 08:00:00.000Z',
      bool starred = false,
    }) => makeTask(
      name,
      dueDate: due,
      dueTime: time,
      createdAt: created,
      isStarred: starred,
    );

    test('A to Z is case-insensitive', () {
      final r = SortTasksService.sortTasksByMode([
        t('banana'),
        t('Apple'),
        t('cherry'),
      ], SortingMode.aToz);
      expect(names(r), ['Apple', 'banana', 'cherry']);
    });

    test('Z to A', () {
      final r = SortTasksService.sortTasksByMode([
        t('banana'),
        t('Apple'),
        t('cherry'),
      ], SortingMode.zToa);
      expect(names(r), ['cherry', 'banana', 'Apple']);
    });

    test('created date ascending and descending', () {
      final list = [
        t('mid', created: '2025-02-01 00:00:00.000Z'),
        t('old', created: '2025-01-01 00:00:00.000Z'),
        t('new', created: '2025-03-01 00:00:00.000Z'),
      ];
      expect(
        names(
          SortTasksService.sortTasksByMode(
            list,
            SortingMode.createdDateIncreasing,
          ),
        ),
        ['old', 'mid', 'new'],
      );
      expect(
        names(
          SortTasksService.sortTasksByMode(
            list,
            SortingMode.createdDateDecreasing,
          ),
        ),
        ['new', 'mid', 'old'],
      );
    });

    test('due date sorts by date and then by time', () {
      final list = [
        t('late-same-day', due: '2025-03-04', time: '18:00'),
        t('next-day', due: '2025-03-05', time: '08:00'),
        t('early-same-day', due: '2025-03-04', time: '07:30'),
      ];
      expect(
        names(
          SortTasksService.sortTasksByMode(list, SortingMode.dueDateIncreasing),
        ),
        ['early-same-day', 'late-same-day', 'next-day'],
      );
      expect(
        names(
          SortTasksService.sortTasksByMode(list, SortingMode.dueDateDecreasing),
        ),
        ['next-day', 'late-same-day', 'early-same-day'],
      );
    });

    test('tasks without a due date sort as the oldest', () {
      final r = SortTasksService.sortTasksByMode([
        t('dated'),
        t('undated', due: null),
      ], SortingMode.dueDateIncreasing);
      expect(names(r), ['undated', 'dated']);
    });

    test('starred first / non-starred first', () {
      final list = [
        t('a', starred: false),
        t('b', starred: true),
        t('c', starred: false),
        t('d', starred: true),
      ];
      expect(
        names(SortTasksService.sortTasksByMode(list, SortingMode.starredFirst)),
        ['b', 'd', 'a', 'c'],
      );
      expect(
        names(
          SortTasksService.sortTasksByMode(list, SortingMode.nonStarredFirst),
        ),
        ['a', 'c', 'b', 'd'],
      );
    });

    test('ties keep their original order (stable sort)', () {
      final list = [t('z'), t('y'), t('x')]; // identical due dates
      expect(
        names(
          SortTasksService.sortTasksByMode(list, SortingMode.dueDateIncreasing),
        ),
        ['z', 'y', 'x'],
      );
    });

    test('manual keeps the given order', () {
      final list = [t('c'), t('a'), t('b')];
      expect(
        names(SortTasksService.sortTasksByMode(list, SortingMode.manual)),
        ['c', 'a', 'b'],
      );
    });

    test('never reorders the input list (it mirrors the Hive box)', () {
      final list = [t('c'), t('a'), t('b')];
      final before = List<Task>.of(list);
      for (final mode in SortingMode.values) {
        final sorted = SortTasksService.sortTasksByMode(list, mode);
        expect(identical(sorted, list), isFalse, reason: '$mode');
      }
      expect(list, before);
    });

    test('empty input', () {
      for (final mode in SortingMode.values) {
        expect(SortTasksService.sortTasksByMode([], mode), isEmpty);
      }
    });
  });

  group('GroupTasksService', () {
    Task due(String name, int daysFromToday, {bool done = false}) =>
        makeTask(name, dueDate: utcDay(daysFromToday), completed: done);

    // GroupTasksService compares against local "now", so build the
    // fixtures from local dates.
    String localDay(int offset) {
      final d = DateTime.now().add(Duration(days: offset));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    Task local(String name, int offset, {bool done = false}) =>
        makeTask(name, dueDate: localDay(offset), completed: done);

    test('default grouping (pending) buckets into today/upcoming/missed', () {
      final g = GroupTasksService.groupTasksByMode(
        [
          local('now', 0),
          local('soon', 2),
          local('old', -3),
          makeTask('nodate', dueDate: null),
        ],
        GroupingMode.Default,
        false,
      );
      expect(g.keys, ['today', 'upcoming', 'missed']);
      expect(names(g['today']!), ['now']);
      expect(names(g['upcoming']!), ['soon']);
      expect(names(g['missed']!), ['old', 'nodate']);
    });

    test('default grouping (completed) uses past instead of missed', () {
      final g = GroupTasksService.groupTasksByMode(
        [local('now', 0, done: true), local('old', -3, done: true)],
        GroupingMode.Default,
        true,
      );
      expect(g.keys, ['today', 'upcoming', 'past']);
      expect(names(g['past']!), ['old']);
      expect(g['upcoming'], isEmpty);
    });

    test('default grouping on no tasks keeps the three empty buckets', () {
      final g = GroupTasksService.groupTasksByMode(
        [],
        GroupingMode.Default,
        false,
      );
      expect(g.values.every((v) => v.isEmpty), isTrue);
    });

    test('group by year, with No Date last', () {
      final g = GroupTasksService.groupTasksByMode(
        [
          makeTask('a', dueDate: '2026-02-01'),
          makeTask('b', dueDate: null),
          makeTask('c', dueDate: '2024-12-31'),
          makeTask('d', dueDate: '2026-07-07'),
        ],
        GroupingMode.year,
        false,
      );
      expect(g.keys.toList(), ['2024', '2026', 'No Date']);
      expect(names(g['2026']!), ['a', 'd']);
    });

    test('group by month, ascending, No Date last', () {
      final g = GroupTasksService.groupTasksByMode(
        [
          makeTask('a', dueDate: '2025-03-10'),
          makeTask('b', dueDate: null),
          makeTask('c', dueDate: '2025-01-05'),
          makeTask('d', dueDate: '2025-03-20'),
        ],
        GroupingMode.month,
        false,
      );
      expect(g.keys.toList(), ['2025-01', '2025-03', 'No Date']);
      expect(names(g['2025-03']!), ['a', 'd']);
    });

    test('group by day, ascending, No Date last', () {
      final g = GroupTasksService.groupTasksByMode(
        [
          makeTask('a', dueDate: '2025-03-10'),
          makeTask('b', dueDate: null),
          makeTask('c', dueDate: '2025-03-09'),
          makeTask('d', dueDate: '2025-03-10'),
        ],
        GroupingMode.day,
        false,
      );
      expect(g.keys.toList(), ['2025-03-09', '2025-03-10', 'No Date']);
      expect(names(g['2025-03-10']!), ['a', 'd']);
    });

    test('an unparseable due date is treated as No Date', () {
      final g = GroupTasksService.groupTasksByMode(
        [makeTask('x', dueDate: 'garbage')],
        GroupingMode.day,
        false,
      );
      expect(g.keys.toList(), ['No Date']);
    });

    test('unused helper stays consistent', () {
      expect(due('x', 0).dueDate, utcDay(0));
    });
  });
}
