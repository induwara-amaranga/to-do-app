import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/types.dart';

void main() {
  group('SubTask', () {
    test('toMap/fromMap round-trip', () {
      final s = SubTask(
        name: 'Read',
        dueDate: '2025-01-02',
        dueTime: '09:30',
        completed: true,
      );
      final copy = SubTask.fromMap(s.toMap());
      expect(copy.name, 'Read');
      expect(copy.dueDate, '2025-01-02');
      expect(copy.dueTime, '09:30');
      expect(copy.completed, isTrue);
    });

    test('fromMap tolerates missing keys', () {
      final s = SubTask.fromMap({});
      expect(s.name, '');
      expect(s.dueDate, isNull);
      expect(s.dueTime, isNull);
      expect(s.completed, isFalse);
    });

    test('defaults to not completed', () {
      expect(SubTask(name: 'x').completed, isFalse);
    });
  });

  group('Task constructor', () {
    test('applies documented defaults', () {
      final t = Task(name: 'A', id: '1');
      expect(t.completed, isFalse);
      expect(t.category, 'None');
      expect(t.priority, 'Medium');
      expect(t.isStarred, isFalse);
      expect(t.source, 'manual');
      expect(t.subtasks, isEmpty);
      expect(t.notificationIds, isEmpty);
      expect(t.remoteEventIds, ['', '', '']);
    });

    test('subtask and notification lists are not shared between tasks', () {
      final a = Task(name: 'A', id: '1');
      final b = Task(name: 'B', id: '2');
      a.subtasks.add(SubTask(name: 's'));
      a.notificationIds.add(7);
      expect(b.subtasks, isEmpty);
      expect(b.notificationIds, isEmpty);
    });
  });

  group('Task.fromList (legacy positional schema)', () {
    test('empty list yields an empty-named task with defaults', () {
      final t = Task.fromList([]);
      expect(t.name, '');
      expect(t.category, 'None');
      expect(t.priority, 'Medium');
      expect(t.source, 'manual');
      expect(t.remoteEventIds, ['', '', '']);
    });

    test('maps every positional field', () {
      final t = Task.fromList([
        'Pay rent', // 0
        true, // 1
        'note', // 2
        '2025-05-01', // 3
        '08:00', // 4
        'Personal', // 5
        'High', // 6
        'monthly', // 7
        15, // 8
        'minutes', // 9
        'true', // 10 legacy string bool
        '2025-04-01 00:00:00.000Z', // 11
        'uuid-1', // 12
        [
          {'name': 'sub', 'completed': true},
        ], // 13
        'calId', // 14
        'evId', // 15
        ['a', 'b', 'c'], // 16
        'google', // 17
        '2025-05-01 08:00:00.000Z', // 18
        [1, 2.0, 'x'], // 19
      ]);
      expect(t.name, 'Pay rent');
      expect(t.completed, isTrue);
      expect(t.note, 'note');
      expect(t.dueDate, '2025-05-01');
      expect(t.dueTime, '08:00');
      expect(t.category, 'Personal');
      expect(t.priority, 'High');
      expect(t.repeatType, 'monthly');
      expect(t.reminderAmount, 15);
      expect(t.reminderType, 'minutes');
      expect(t.isStarred, isTrue);
      expect(t.createdAt, '2025-04-01 00:00:00.000Z');
      expect(t.id, 'uuid-1');
      expect(t.subtasks.single.name, 'sub');
      expect(t.subtasks.single.completed, isTrue);
      expect(t.localCalendarId, 'calId');
      expect(t.localEventId, 'evId');
      expect(t.remoteEventIds, ['a', 'b', 'c']);
      expect(t.source, 'google');
      expect(t.completedAt, '2025-05-01 08:00:00.000Z');
      expect(t.notificationIds, [1, 2]); // non-numbers dropped
    });

    test('accepts SubTask instances and skips junk subtask entries', () {
      final raw = List<dynamic>.filled(14, null);
      raw[0] = 'x';
      raw[13] = [SubTask(name: 'keep'), 42, null];
      final t = Task.fromList(raw);
      expect(t.subtasks.map((s) => s.name), ['keep']);
    });

    test('isStarred accepts bool true and string "false"', () {
      final a = List<dynamic>.filled(11, null)..[10] = true;
      final b = List<dynamic>.filled(11, null)..[10] = 'false';
      expect(Task.fromList(a).isStarred, isTrue);
      expect(Task.fromList(b).isStarred, isFalse);
    });
  });

  group('CalendarEvent', () {
    test('defaults differ from Task (Low priority, local source)', () {
      final e = CalendarEvent(name: 'E', id: '1');
      expect(e.priority, 'Low');
      expect(e.source, 'local');
      expect(e.remoteEventId, '');
    });

    test('fromList keeps remote id at index 16 as a single String', () {
      final raw = List<dynamic>.filled(19, null);
      raw[0] = 'Meeting';
      raw[12] = 'id-9';
      raw[14] = 'cal';
      raw[15] = 'evt';
      raw[16] = 'remote-123';
      raw[17] = 'outlook';
      final e = CalendarEvent.fromList(raw);
      expect(e.name, 'Meeting');
      expect(e.id, 'id-9');
      expect(e.calendarId, 'cal');
      expect(e.eventId, 'evt');
      expect(e.remoteEventId, 'remote-123');
      expect(e.source, 'outlook');
    });

    test('fromList on empty list uses defaults', () {
      final e = CalendarEvent.fromList([]);
      expect(e.name, '');
      expect(e.priority, 'Low');
      expect(e.source, 'local');
    });
  });

  group('enums and constants', () {
    test('every SortingMode has a distinct display name', () {
      final names = SortingMode.values.map((m) => m.displayName).toSet();
      expect(names.length, SortingMode.values.length);
      expect(SortingMode.aToz.displayName, 'A to Z');
      expect(SortingMode.manual.displayName, 'Manual');
    });

    test('GroupingMode exposes the four modes', () {
      expect(GroupingMode.values, [
        GroupingMode.Default,
        GroupingMode.day,
        GroupingMode.month,
        GroupingMode.year,
      ]);
    });

    test('type lists', () {
      expect(repeatTypes, ['none', 'daily', 'weekly', 'monthly', 'yearly']);
      expect(priorityTypes, ['Low', 'Medium', 'High']);
      expect(remainderTypes, contains('none'));
    });
  });
}
