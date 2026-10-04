import 'dart:io';

import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';

int _seq = 0;

/// Builds a [Task] with sensible defaults. `dueTime` defaults to "10:00"
/// because the sort/filter/repeat services force-unwrap it.
Task makeTask(
  String name, {
  bool completed = false,
  String? note,
  String? dueDate = '2025-03-04',
  String? dueTime = '10:00',
  String category = 'None',
  String priority = 'Medium',
  String? repeatType = 'none',
  int reminderAmount = -1,
  String? reminderType = 'none',
  bool isStarred = false,
  String? createdAt = '2025-01-01 08:00:00.000Z',
  String? id,
  List<SubTask>? subtasks,
  String source = 'manual',
}) {
  return Task(
    name: name,
    completed: completed,
    note: note,
    dueDate: dueDate,
    dueTime: dueTime,
    category: category,
    priority: priority,
    repeatType: repeatType,
    reminderAmount: reminderAmount,
    reminderType: reminderType,
    isStarred: isStarred,
    createdAt: createdAt,
    id: id ?? 'id-${_seq++}',
    subtasks: subtasks,
    source: source,
    completedAt: 'none',
  );
}

CalendarEvent makeEvent(
  String name, {
  String source = 'google',
  String dueDate = '2025-03-04',
  String dueTime = '10:00',
  String calendarId = 'cal-1',
  String remoteEventId = 'remote-1',
}) {
  return CalendarEvent(
    name: name,
    dueDate: dueDate,
    dueTime: dueTime,
    id: 'ev-${_seq++}',
    calendarId: calendarId,
    eventId: remoteEventId,
    remoteEventId: remoteEventId,
    source: source,
    completedAt: 'none',
  );
}

/// `yyyy-MM-dd` for [daysFromToday] days from today, using UTC calendar dates
/// (the app stores due dates as UTC values).
String utcDay(int daysFromToday) {
  final d = DateTime.now().toUtc().add(Duration(days: daysFromToday));
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

bool _tzReady = false;

/// Loads the timezone database and pins `tz.local` so conversions are
/// deterministic regardless of the machine running the tests.
void initTestTimeZone([String name = 'Asia/Colombo']) {
  if (!_tzReady) {
    tz_data.initializeTimeZones();
    _tzReady = true;
  }
  tz.setLocalLocation(tz.getLocation(name));
}

/// A real [ToDoDataBase] backed by Hive in a throw-away directory.
class TestDb {
  final Directory dir;
  final ToDoDataBase db;
  TestDb._(this.dir, this.db);

  static Future<TestDb> open() async {
    final dir = await Directory.systemTemp.createTemp('todo_test_');
    Hive.init(dir.path);
    final db = ToDoDataBase();
    await db.openBoxes();
    return TestDb._(dir, db);
  }

  Future<void> dispose() async {
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}
