import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/notification_service.dart';

/// Automatic removal of old past tasks (Settings > Preferences).
///
/// With a limit of N, the N most recent *past* tasks are kept and every older
/// past task is deleted. A task is past when its due date is before
/// yesterday (UTC); the extra day means nothing due today is ever touched,
/// whatever the user's time zone. Tasks with no due date, and everything due
/// recently or in the future, are never removed. Completed and missed tasks
/// count the same.
class PastTaskCleanup {
  /// Options offered in Settings: keep-latest limit -> label. 0 = never.
  static const Map<int, String> options = {
    0: 'Never remove',
    500: 'Keep latest 500 tasks',
    1000: 'Keep latest 1000 tasks',
    2000: 'Keep latest 2000 tasks',
  };

  /// Label for [keepLatest], falling back to a generic one for odd values.
  static String label(int keepLatest) =>
      options[keepLatest] ?? 'Keep latest $keepLatest tasks';

  /// Due date and time as a comparable moment, or null if there is no
  /// usable due date.
  static DateTime? _due(Task t) {
    final date = t.dueDate;
    if (date == null || date.isEmpty || date == '0000-00-00') return null;
    final d = DateTime.tryParse(date);
    if (d == null) return null;
    final parts = (t.dueTime ?? '').split(':');
    final h = parts.length > 1 ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime.utc(d.year, d.month, d.day, h.clamp(0, 23), m.clamp(0, 59));
  }

  /// The tasks that would be removed for [keepLatest] (oldest first). Never
  /// modifies [tasks]. Empty when [keepLatest] is 0 or negative.
  static List<Task> selectRemovable(
    List<Task> tasks,
    int keepLatest, {
    DateTime? now,
  }) {
    if (keepLatest <= 0) return [];
    final utc = (now ?? DateTime.now()).toUtc();
    final cutoff = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).subtract(const Duration(days: 1));

    final past = <({Task task, DateTime due, int pos})>[];
    for (var i = 0; i < tasks.length; i++) {
      final due = _due(tasks[i]);
      if (due != null && due.isBefore(cutoff)) {
        past.add((task: tasks[i], due: due, pos: i));
      }
    }
    if (past.length <= keepLatest) return [];

    // Newest first; ties keep list order so the result is deterministic.
    past.sort((a, b) {
      final c = b.due.compareTo(a.due);
      return c != 0 ? c : a.pos.compareTo(b.pos);
    });
    final doomed = [for (final e in past.skip(keepLatest)) e.task];
    return doomed.reversed.toList();
  }

  /// Applies the saved limit to [db]: removes the tasks from the list and the
  /// box in one batch and cancels their reminders. Returns how many were
  /// removed. Calendar events are left alone: this only tidies the local list.
  static Future<int> run(
    ToDoDataBase db, {
    DateTime? now,
    Future<void> Function(int id)? cancelNotification,
  }) async {
    final doomed = selectRemovable(
      db.toDoList,
      db.settings.keepLatestPastTasks,
      now: now,
    );
    if (doomed.isEmpty) return 0;

    final cancel = cancelNotification ?? NotificationService.cancelNotification;
    for (final task in doomed) {
      for (final id in task.notificationIds) {
        try {
          await cancel(id);
        } catch (_) {
          // A reminder that can't be cancelled must not block the cleanup.
        }
      }
    }
    await db.removeTasks(doomed);
    return doomed.length;
  }
}
