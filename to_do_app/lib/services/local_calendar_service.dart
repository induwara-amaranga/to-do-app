import 'package:device_calendar/device_calendar.dart';
import 'package:device_calendar/device_calendar.dart' as tz;
import 'package:flutter/material.dart%20';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:uuid/uuid.dart';

final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin(
  shouldInitTimezone: false,
);
var uuid = Uuid();

class LocalCalendarService {
  static Future<bool> hasCalendarPermission() async {
    final r = await _deviceCalendarPlugin.hasPermissions();
    return r.isSuccess && r.data == true;
  }

  static Future<bool> requestCalendarPermission() async {
    final r = await _deviceCalendarPlugin.requestPermissions();
    return r.isSuccess && r.data == true;
  }

  static Future<List<Calendar>> getCalendars() async {
    try {
      // Request permissions if not granted
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (!permissionsGranted.isSuccess || permissionsGranted.data == false) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      }

      if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
        final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();

        return calendarsResult.data ?? [];
      } else {}
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getEvents(String? calendarId) async {
    if (calendarId == null) {
      return [];
    }
    final startDate = DateTime.now().subtract(const Duration(days: 60));
    final endDate = DateTime.now().add(const Duration(days: 60));

    final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(startDate: startDate, endDate: endDate),
    );

    final events = eventsResult.data ?? [];
    return events;
  }

  static Future<void> addEvent(String calendarId, Task task) async {
    try {
      // Parse due date and time
      final dueDate = DateTimeUtilsHelper.parseDate(task.dueDate);
      final dueTime = DateTimeUtilsHelper.parseDate(task.dueTime);
      RecurrenceRule? recurrenceRule = _buildRecurrenceRule(task.repeatType);

      if (dueDate == null) {
        return;
      }

      // Build start/end as TZDateTime
      final now = tz.TZDateTime.from(
        DateTime.now().subtract(const Duration(minutes: 15)),
        tz.local,
      );
      final startCombined = DateTimeUtilsHelper.combineDateAndTime(
        DateTimeUtilsHelper.parseDate(task.dueDate)!,
        DateTimeUtilsHelper.parseTime(task.dueTime!)!,
      );

      final start = //start.add(const Duration(hours: 1));
          dueTime != null
              ? tz.TZDateTime.from(
                DateTimeUtilsHelper.toLocalUsingTz(startCombined),
                tz.local,
              )
              : now.add(const Duration(hours: 1));
      // 30 minutes after start, but never past the end of the task's own day.
      final end = tz.TZDateTime.from(
        DateTimeUtilsHelper.eventEnd(start),
        tz.local,
      );

      if (!end.isAfter(start)) {
        end.add(const Duration(minutes: 30));
      }

      final event = Event(
        calendarId,
        title: task.name,
        description: task.note ?? '',
        start: start,
        end: end,
        eventId: task.remoteEventIds[0],
        recurrenceRule: recurrenceRule,
      );

      // 1️⃣ Retrieve events in a small window around this time
      final events = await LocalCalendarService.getEvents(calendarId);
      //final events = eventsResult.data ?? [];
      // for (var event in events) {
      // }

      // 2️⃣ Check if an event with the same title and start time exists
      // 2️⃣ Check if an event with the same ID exists
      final exists = events.cast<Event?>().firstWhere((e) {
        return e != null && e.eventId == task.remoteEventIds[0];
      }, orElse: () => null);

      if (exists != null) {
        event.eventId = exists.eventId;
        //return;
        //return;
      } else {
        event.eventId = null; // Ensure new event is created
      }

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);

      if (result!.isSuccess && result.data != null) {
        task.remoteEventIds[0] = result.data;
      } else {
        throw Exception(
          '❌ Failed to create event.task=$task Success=${result.isSuccess}, '
          'Data=${result.data}, Errors=${result.errors.toString()}',
        );
      }
    } catch (e) {
      throw Exception('❌ Exception while creating event: $e task=$task ');
    }
  }

  static Future<void> deleteEvent(String? eventId, String? calendarId) async {
    final result = await _deviceCalendarPlugin.deleteEvent(calendarId, eventId);

    // 3️⃣ Handle result
    if (result.isSuccess && result.data == true) {
    } else {}
  }

  // static Future<void> importCalendarEventsToDB(
  //   List<dynamic>? events,
  //   ToDoDataBase db,
  // ) async {
  //   if (events == null || events.isEmpty) {
  //     return;
  //   }

  //   int importedCount = 0;
  //   for (final event in events) {
  //     if (event.start == null) continue;

  //     // Skip if this event already exists in toDoList
  //     final exists = db.toDoList.any(
  //       (task) =>
  //           task.length > 15 && // ensure extended structure
  //           task[14] == event.calendarId &&
  //           task[15] == event.eventId,
  //     );

  //     if (exists) {
  //       continue;
  //     }

  //     // Parse start time into date/time strings
  //     final start = event.start!;
  //     final parts = start.toIso8601String().split('T');
  //     final dueDate = parts.first;
  //     final dueTime = parts.length > 1 ? parts[1] : '00:00:00';

  //     final taskDetails = {
  //       'taskName': event.title ?? 'Untitled Event',
  //       'taskNote': event.description ?? '',
  //       'dueDate': dueDate,
  //       'dueTime': dueTime,
  //       'taskCategory': 'None',
  //       'taskPriority': 'Low',
  //       'repeatType': 'none',
  //       'remainderAmount': 10,
  //       'remainderType': 'none',
  //       'isStarred': false,
  //       'createdAt': DateTime.now().toIso8601String(),
  //       'subTasks': [],
  //       'calendarId': event.calendarId,
  //       'eventId': event.eventId,
  //     };

  //     db.toDoList.add([
  //       taskDetails['taskName'],
  //       false,
  //       taskDetails['taskNote'],
  //       taskDetails['dueDate'],
  //       taskDetails['dueTime'],
  //       taskDetails['taskCategory'],
  //       taskDetails['taskPriority'],
  //       taskDetails['repeatType'],
  //       taskDetails['remainderAmount'],
  //       taskDetails['remainderType'],
  //       taskDetails['isStarred'],
  //       taskDetails['createdAt'],
  //       uuid.v4(),
  //       taskDetails['subTasks'],
  //       taskDetails['calendarId'], // store calendar ID
  //       taskDetails['eventId'],
  //     ]);

  //     importedCount++;
  //   }

  //   db.updateDataBase();
  //   db.loadData();
  // }

  static Future<void> importCalendarEventsToDB(
    List<dynamic>? events,
    ToDoDataBase db,
  ) async {
    if (events == null || events.isEmpty) {
      return;
    }

    for (final event in events) {
      if (event.start == null) continue;

      // Parse start time into date/time strings
      final start = event.start!;
      final parts = start.toIso8601String().split('T');
      final dueDate = parts.first;
      final dueTime = parts.length > 1 ? parts[1] : '00:00:00';

      final taskDetails = {
        'taskName': event.title ?? 'Untitled Event',
        'taskNote': event.description ?? '',
        'dueDate': dueDate,
        'dueTime': dueTime,
        'taskCategory': 'None',
        'taskPriority': 'Low',
        'repeatType': _repeatTypeFromRule(event.recurrenceRule),
        'remainderAmount': 10,
        'remainderType': 'none',
        'isStarred': false,
        'createdAt': DateTime.now().toUtc().toString(),
        'subTasks': [],
        'calendarId': event.calendarId,
        'eventId': event.eventId,
      };

      // Find if this event already exists
      final existingIndex = db.toDoList.indexWhere((task) {
        return task.localCalendarId == event.calendarId &&
            task.remoteEventIds[0] == event.eventId;
      });

      if (existingIndex != -1) {
        // Update existing task
        final t = db.toDoList[existingIndex];
        t.name = taskDetails['taskName'] as String;
        t.note = taskDetails['taskNote'] as String;
        t.dueDate = taskDetails['dueDate'] as String;
        t.dueTime = taskDetails['dueTime'] as String;
        t.category = taskDetails['taskCategory'] as String;
        t.priority = taskDetails['taskPriority'] as String;
        t.repeatType = taskDetails['repeatType'] as String;
        t.reminderAmount = taskDetails['remainderAmount'] as int;
        t.reminderType = taskDetails['remainderType'] as String;
        t.isStarred = taskDetails['isStarred'] as bool;
        t.subtasks = [];
        continue;
      }

      // Otherwise, add new task
      db.toDoList.add(
        Task(
          name: taskDetails['taskName'] as String,
          completed: false,
          note: taskDetails['taskNote'] as String,
          dueDate: taskDetails['dueDate'] as String,
          dueTime: taskDetails['dueTime'] as String,
          category: taskDetails['taskCategory'] as String,
          priority: taskDetails['taskPriority'] as String,
          repeatType: taskDetails['repeatType'] as String,
          reminderAmount: taskDetails['remainderAmount'] as int,
          reminderType: taskDetails['remainderType'] as String,
          isStarred: taskDetails['isStarred'] as bool,
          createdAt: taskDetails['createdAt'] as String,
          id: uuid.v4(),
          subtasks: [],
          localCalendarId: taskDetails['calendarId'] as String,
          localEventId: taskDetails['eventId'] as String,
          remoteEventIds: [taskDetails['eventId'], "", ""],
          source: "local calendar",
          completedAt: "none",
          notificationIds: [],
        ),
      );
    }

    await db.saveToDoList();
  }

  // static Future<void> importToDoCalendarEventsToDB(
  //   List<dynamic>? events,
  //   ToDoDataBase db,
  // ) async {
  //   if (events == null || events.isEmpty) {
  //     return;
  //   }

  //   int importedCount = 0;
  //   int updatedCount = 0;

  //   for (final event in events) {
  //     if (event.start == null) continue;

  //     // Parse start time into date/time strings
  //     final _start = event.start!;
  //     DateTime start = DateTimeUtilsHelper.toUtcUsingLocal(_start);
  //     start = DateTimeUtilsHelper.toUtcUsingLocal(start);
  //     final parts = start.toIso8601String().split('T');
  //     final dueDate = parts.first;
  //     final dueTime = parts.length > 1 ? parts[1] : '00:00:00';

  //     final taskDetails = {
  //       'taskName': event.title ?? 'Untitled Event',
  //       'taskNote': event.description ?? '',
  //       'dueDate': dueDate,
  //       'dueTime': dueTime,
  //       'taskCategory': 'None',
  //       'taskPriority': 'Low',
  //       'repeatType': 'none',
  //       'remainderAmount': 10,
  //       'remainderType': 'none',
  //       'isStarred': false,
  //       'createdAt': DateTime.now().toUtc().toString(),
  //       'subTasks': [],
  //       'calendarId': event.calendarId,
  //       'eventId': event.eventId,
  //     };

  //     // Find if this event already exists
  //     final existingIndex = db.toDoList.indexWhere(
  //       (task) =>
  //           task.length > 15 &&
  //           task[14] == event.calendarId &&
  //           task[15] == event.eventId,
  //     );

  //     final combined = DateTimeUtilsHelper.combineDateAndTime(
  //       DateTimeUtilsHelper.parseDate(taskDetails['dueDate']),

  //       DateTimeUtilsHelper.parseDate(taskDetails['dueTime']),
  //     );
  //     final utcTime = DateTimeUtilsHelper.toUtcUsingLocal(combined);
  //     if (existingIndex != -1) {
  //       // Update existing task
  //       db.localCalTasks[existingIndex][0] = taskDetails['taskName'];
  //       db.localCalTasks[existingIndex][2] = taskDetails['taskNote'];
  //       db.localCalTasks[existingIndex][3] = DateTimeUtilsHelper.formatDate(utcTime);
  //       db.localCalTasks[existingIndex][4] = DateTimeUtilsHelper.formatTime(utcTime);
  //       db.localCalTasks[existingIndex][5] = taskDetails['taskCategory'];
  //       db.localCalTasks[existingIndex][6] = taskDetails['taskPriority'];
  //       db.localCalTasks[existingIndex][7] = taskDetails['repeatType'];
  //       db.localCalTasks[existingIndex][8] = taskDetails['remainderAmount'];
  //       db.localCalTasks[existingIndex][9] = taskDetails['remainderType'];
  //       db.localCalTasks[existingIndex][10] = taskDetails['isStarred'];
  //       db.localCalTasks[existingIndex][13] = taskDetails['subTasks'];
  //       updatedCount++;
  //       continue;
  //     }

  //     // Otherwise, add new task
  //     db.localCalTasks.add([
  //       taskDetails['taskName'],
  //       false,
  //       taskDetails['taskNote'],
  //       DateTimeUtilsHelper.formatDate(utcTime),
  //       DateTimeUtilsHelper.formatTime(utcTime),
  //       taskDetails['taskCategory'],
  //       taskDetails['taskPriority'],
  //       taskDetails['repeatType'],
  //       taskDetails['remainderAmount'],
  //       taskDetails['remainderType'],
  //       taskDetails['isStarred'],
  //       taskDetails['createdAt'],
  //       uuid.v4(),
  //       taskDetails['subTasks'],
  //       taskDetails['calendarId'], // store calendar ID
  //       taskDetails['eventId'],
  //       taskDetails['eventId'],
  //       false,
  //     ]);

  //     importedCount++;
  //   }

  //   db.updateDataBase();
  //   db.loadData();
  // }

  static Future<Calendar> createNewCalendar(List<Calendar> calendars) async {
    // Get existing calendars

    // Check for existing “ToDoList” calendar
    final existing = calendars.firstWhere(
      (cal) => cal.name?.toLowerCase() == 'todolist',
      orElse: () => Calendar(id: ''),
    );

    if (existing.id != null && existing.id!.isNotEmpty) {
      return existing; // Already exists
    }

    // Create a new local calendar
    // final newCalendar = Calendar(
    //   name: 'ToDoList',
    //   isReadOnly: false,
    //   color: 0xFF2196F3, // blue
    //   accountName: 'ToDo App',
    // );

    final createResult = await _deviceCalendarPlugin.createCalendar(
      'ToDoList',
      calendarColor: Colors.red, // blue color
    );
    if (createResult.isSuccess && createResult.data != null) {
      // Retrieve the newly created calendar
      final created = (await getCalendars()).firstWhere(
        (cal) => cal.id == createResult.data,
      );
      return created;
    } else {
      throw Exception("Failed to create ToDoList calendar");
    }
  }

  static Future<void> syncTasksToCalendar(
    ToDoDataBase db,
    String calendarID,
  ) async {
    //final calendar = await ensureToDoListCalendar();
    final tasksToSync = List<Task>.from(db.toDoList);
    for (var task in tasksToSync) {
      if (task.source == "repeat") continue;
      try {
        await addEvent(calendarID, task);
      } catch (_) {}
    }
  }

  static Future<void> syncTasksFromCalendar(ToDoDataBase db) async {
    final calID = db.syncToCalendars["local"];
    //db.localCalTasks.removeWhere((t) => t[14] == calID);
    List<dynamic> events = await getEvents(calID);
    await importViewOnlyEventsToDB(events, db, replace: true);
  }

  ///
  /// With [replace], the cached local-calendar events are swapped for exactly
  /// [events] (see GoogleCalendarService.importViewOnlyEventsToDB).
  static Future<void> importViewOnlyEventsToDB(
    List<dynamic>? events,
    ToDoDataBase db, {
    bool replace = false,
  }) async {
    // No db.loadData() here: it replaced every in-memory list with the disk
    // copy mid-sync, which is unsafe now that providers sync concurrently.
    if (replace && events != null) db.localCalTasks.clear();
    if (events == null || events.isEmpty) {
      if (replace && events != null) await db.saveLocalCalTasks();
      return;
    }

    // Recurring events expand into many instances with the same eventId.
    // Keep only the earliest instance per eventId so we import the start date.
    final Map<String, dynamic> earliestByEventId = {};
    for (final event in events) {
      if (event.start == null || event.eventId == null) continue;
      final existing = earliestByEventId[event.eventId];
      if (existing == null ||
          (event.start as DateTime).isBefore(existing.start as DateTime)) {
        earliestByEventId[event.eventId] = event;
      }
    }
    final deduplicatedEvents = earliestByEventId.values.toList();

    for (final event in deduplicatedEvents) {
      if (event.start == null) continue;

      // Convert event start to UTC; strip milliseconds/Z from time part
      final startUtc = DateTimeUtilsHelper.toUtcUsingLocal(event.start!);
      final isoParts = startUtc.toIso8601String().split('T');
      final dueDate = isoParts.first;
      final dueTime =
          isoParts.length > 1
              ? isoParts[1].split('.').first.replaceAll('Z', '')
              : '00:00:00';

      final taskDetails = {
        'taskName': event.title ?? 'Untitled Event',
        'taskNote': event.description ?? '',
        'dueDate': dueDate,
        'dueTime': dueTime,
        'taskCategory': 'None',
        'taskPriority': 'Low',
        'repeatType': _repeatTypeFromRule(event.recurrenceRule),
        'remainderAmount': 10,
        'remainderType': 'none',
        'isStarred': false,
        'createdAt': DateTime.now().toUtc().toString(),
        'subTasks': [],
        'calendarId': event.calendarId,
        'eventId': event.eventId,
      };

      // Find if this event already exists
      final existingIndex = db.localCalTasks.indexWhere(
        (task) => task.remoteEventId == event.eventId,
      );

      if (existingIndex != -1) {
        // Update existing task
        final t = db.localCalTasks[existingIndex];
        t.name = taskDetails['taskName'] as String;
        t.note = taskDetails['taskNote'] as String;
        t.dueDate = dueDate;
        t.dueTime = dueTime;
        t.category = taskDetails['taskCategory'] as String;
        t.priority = taskDetails['taskPriority'] as String;
        t.repeatType = taskDetails['repeatType'] as String;
        t.reminderAmount = taskDetails['remainderAmount'] as int;
        t.reminderType = taskDetails['remainderType'] as String;
        t.isStarred = taskDetails['isStarred'] as bool;
        t.subtasks = [];
        continue;
      }

      // Otherwise, add new task
      db.localCalTasks.add(
        CalendarEvent(
          name: taskDetails['taskName'] as String,
          completed: false,
          note: taskDetails['taskNote'] as String,
          dueDate: dueDate,
          dueTime: dueTime,
          category: taskDetails['taskCategory'] as String,
          priority: taskDetails['taskPriority'] as String,
          repeatType: taskDetails['repeatType'] as String,
          reminderAmount: taskDetails['remainderAmount'] as int,
          reminderType: taskDetails['remainderType'] as String,
          isStarred: taskDetails['isStarred'] as bool,
          createdAt: taskDetails['createdAt'] as String,
          id: uuid.v4(),
          subtasks: [],
          calendarId: taskDetails['calendarId'] as String,
          eventId: taskDetails['eventId'] as String,
          remoteEventId: taskDetails['eventId'] as String,
          source: "local",
          completedAt: "none",
        ),
      );
    }

    await db.saveLocalCalTasks();
  }

  static String _repeatTypeFromRule(RecurrenceRule? rule) {
    if (rule == null) return 'none';
    switch (rule.recurrenceFrequency) {
      case RecurrenceFrequency.Daily:
        return 'daily';
      case RecurrenceFrequency.Weekly:
        return 'weekly';
      case RecurrenceFrequency.Monthly:
        return 'monthly';
      case RecurrenceFrequency.Yearly:
        return 'yearly';
      default:
        return 'none';
    }
  }

  static RecurrenceRule? _buildRecurrenceRule(String? repeatType) {
    if (repeatType == null || repeatType == 'none' || repeatType == 'None') {
      return null; // no repeat
    }

    switch (repeatType.toLowerCase()) {
      case 'daily':
        return RecurrenceRule(RecurrenceFrequency.Daily, interval: 1);

      case 'weekly':
        return RecurrenceRule(RecurrenceFrequency.Weekly, interval: 1);

      case 'monthly':
        return RecurrenceRule(RecurrenceFrequency.Monthly, interval: 1);

      case 'yearly':
        return RecurrenceRule(RecurrenceFrequency.Yearly, interval: 1);

      default:
        return null;
    }
  }
}
