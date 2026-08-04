import 'package:flutter/widgets.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:uuid/uuid.dart';

class RepeatTask {
  static var uuid = Uuid();

  /// Identity of one occurrence: same task name on the same calendar day.
  /// Matches the name + y/m/d comparison the duplicate check has always used.
  static String _occurrenceKey(String name, DateTime date) =>
      '$name|${date.year}-${date.month}-${date.day}';

  /// Every occurrence currently in [db], as a lookup set. Tasks whose stored
  /// due date won't parse are skipped rather than throwing.
  static Set<String> _existingOccurrences(ToDoDataBase db) {
    final keys = <String>{};
    for (final t in db.toDoList) {
      final d = DateTimeUtilsHelper.parseDate(t.dueDate);
      if (d != null) keys.add(_occurrenceKey(t.name, d));
    }
    return keys;
  }

  // Create all pending repeated tasks if their due date(s) have passed
  static void createPendingRepeatTasks(
    ToDoDataBase db,
    BuildContext context,
  ) async {
    final today = DateTime.now().toUtc();

    // Make a copy so iteration isn’t affected by .add()
    final originalTasks = List<Task>.from(db.toDoList);

    // Built once, then kept current as occurrences are appended. The catch-up
    // loop below can run hundreds of iterations for a long-neglected daily
    // task; scanning the whole task list inside each one made the backfill
    // O(missed occurrences × task count).
    final existingKeys = _existingOccurrences(db);

    for (var task in originalTasks) {
      // Skip if task has no repeat type
      if (task.repeatType == null || task.repeatType == "none") continue;

      // Parse due date
      DateTime? dueDate = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(
        DateTimeUtilsHelper.combineDateAndTime(
          DateTimeUtilsHelper.parseDate(task.dueDate),
          DateTimeUtilsHelper.parseTime(task.dueTime!),
        ),
      );
      if (dueDate == null) continue;

      // Add repeated tasks until dueDate is in the future
      int maxRepeats = 1000; // safety cap
      int count = 0;

      while (!dueDate!.isAfter(DateTime(today.year, today.month, today.day)) &&
          count < maxRepeats) {
        dueDate = await _createNextRepeatTask(
          context,
          db,
          task,
          dueDate,
          existingKeys,
        );
        count++;
      }
    }

    // Only the task list changed — no need to rewrite the calendar boxes.
    db.saveToDoList();
  }

  // Private helper to create the next repeat task
  // Returns the next due date
  static Future<DateTime> _createNextRepeatTask(
    BuildContext context,
    ToDoDataBase db,
    Task task,
    DateTime dueDate,
    Set<String> existingKeys,
  ) async {
    String repeatType = task.repeatType!;
    DateTime nextDate;

    switch (repeatType) {
      case "daily":
        nextDate = dueDate.add(Duration(days: 1));
        break;
      case "weekly":
        nextDate = dueDate.add(Duration(days: 7));
        break;
      case "monthly":
        nextDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
        break;
      case "yearly":
        nextDate = DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
        break;
      default:
        return dueDate; // unknown repeat type
    }
    String id = uuid.v4();

    // O(1) duplicate check against the set built once by the caller.
    final key = _occurrenceKey(task.name, nextDate);
    if (!existingKeys.add(key)) return nextDate;

    db.toDoList.add(
      Task(
        name: task.name,
        completed: false,
        note: task.note,
        dueDate: DateTimeUtilsHelper.formatDate(nextDate),
        dueTime: task.dueTime,
        category: task.category,
        priority: task.priority,
        repeatType: task.repeatType,
        reminderAmount: task.reminderAmount,
        reminderType: task.reminderType,
        isStarred: task.isStarred,
        createdAt: DateTime.now().toUtc().toString(),
        id: id,
        subtasks: task.subtasks,
        localCalendarId: task.localCalendarId,
        localEventId: task.localEventId,
        remoteEventIds: task.remoteEventIds,
        source: "repeat",
        completedAt: "none",
        notificationIds: [],
      ),
    );
    //if due date and time  is after now  then schedule notification
    DateTime now = DateTime.now().toUtc();
    if (nextDate.isAfter(DateTime(now.year, now.month, now.day))) {
      //schedule notification
      if (task.reminderAmount >= 0) {
        DateTime? dueTime = DateTimeUtilsHelper.parseTime(task.dueTime!);
        if (dueTime != null) {
          DateTime remainderDateTime = NotificationService.remainderDateTime(
            nextDate,
            dueTime,
            task.reminderType!,
            task.reminderAmount,
          );
          if (remainderDateTime.isAfter(DateTime.now().toUtc())) {
            await NotificationService.scheduleInitialRemainderForTask(
              id,
              context,
              {
                'dueDate': DateTimeUtilsHelper.formatDate(nextDate),
                'dueTime': task.dueTime,
                'taskName': task.name,
                'taskPriority': task.priority,
                'remainderType': task.reminderType,
                'remainderAmount': task.reminderAmount,
              },
              db,
              db.toDoList.length - 1,
            );
          }
        }
      }
    }

    return nextDate;
  }

  static Future<void> createNextRepeatTask(
    BuildContext context,
    int index,
    ToDoDataBase db,
  ) async {
    var task = db.toDoList[index];

    // Parse the current due date
    DateTime? dueDate = DateTimeUtilsHelper.parseDate(task.dueDate);
    if (dueDate == null) return;

    // Only create next task if current date is after due date
    DateTime today = DateTime.now().toUtc();
    if (DateTime(today.year, today.month, today.day).isAfter(dueDate)) {
      //Due date not passed yet, don't create next task
      return;
    }

    // Calculate next due date
    String repeatType = task.repeatType!; // daily, weekly, monthly, yearly
    DateTime nextDate;
    switch (repeatType) {
      case "daily":
        nextDate = dueDate.add(Duration(days: 1));
        break;
      case "weekly":
        nextDate = dueDate.add(Duration(days: 7));
        break;
      case "monthly":
        nextDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
        break;
      case "yearly":
        nextDate = DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
        break;
      default:
        return;
    }
    String id = uuid.v4();

    // Single scan, and it no longer force-unwraps parseDate — a task with an
    // unparseable stored due date is skipped instead of throwing.
    final alreadyExists = db.toDoList.any((t) {
      if (t.name != task.name) return false;
      final d = DateTimeUtilsHelper.parseDate(t.dueDate);
      return d != null &&
          d.year == nextDate.year &&
          d.month == nextDate.month &&
          d.day == nextDate.day;
    });
    if (alreadyExists) return;

    // Add the new repeated task
    db.toDoList.add(
      Task(
        name: task.name,
        completed: false,
        note: task.note,
        dueDate: DateTimeUtilsHelper.formatDate(nextDate),
        dueTime: task.dueTime,
        category: task.category,
        priority: task.priority,
        repeatType: task.repeatType,
        reminderAmount: task.reminderAmount,
        reminderType: task.reminderType,
        isStarred: task.isStarred,
        createdAt: DateTime.now().toUtc().toString(),
        id: id,
        subtasks: task.subtasks,
        localCalendarId: task.localCalendarId,
        localEventId: task.localEventId,
        remoteEventIds: task.remoteEventIds,
        source: "repeat",
        completedAt: "none",
        notificationIds: [],
      ),
    );

    // Only the task list changed.
    db.saveToDoList();
    if (task.reminderAmount >= 0) {
      DateTime? dueTime = DateTimeUtilsHelper.parseTime(task.dueTime!);
      if (dueTime != null) {
        DateTime remainderDateTime = NotificationService.remainderDateTime(
          nextDate,
          dueTime,
          task.reminderType!,
          task.reminderAmount,
        );
        if (remainderDateTime.isAfter(DateTime.now().toUtc())) {
          await NotificationService.scheduleInitialRemainderForTask(
            id,
            context,
            {
              'dueDate': DateTimeUtilsHelper.formatDate(nextDate),
              'dueTime': task.dueTime,
              'taskName': task.name,
              'taskPriority': task.priority,
              'remainderType': task.reminderType,
              'remainderAmount': task.reminderAmount,
            },
            db,
            db.toDoList.length - 1,
          );
        }
      }
    }
  }
}
