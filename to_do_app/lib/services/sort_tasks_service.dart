import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class SortTasksService {
  /// Returns a sorted **copy** of [tasks]; the input list is never reordered.
  ///
  /// The "All" tab passes `db.toDoList` straight in. Sorting that in place
  /// reordered the in-memory list away from the Hive box, and since
  /// `saveTaskAt(i)` writes `toDoList[i]` to box slot `i`, the next toggle or
  /// edit overwrote a *different* task's record on disk.
  ///
  /// Sort keys are computed once per task up front rather than inside the
  /// comparator, which otherwise re-derives both keys on each of the
  /// O(n log n) comparisons.
  static List<Task> sortTasksByMode(List<Task> tasks, SortingMode mode) {
    switch (mode) {
      case SortingMode.aToz:
        return _sortedBy(tasks, (t) => t.name.toLowerCase());
      case SortingMode.zToa:
        return _sortedBy(tasks, (t) => t.name.toLowerCase(), descending: true);
      case SortingMode.createdDateIncreasing:
        return _sortedBy(tasks, _createdKey);
      case SortingMode.createdDateDecreasing:
        return _sortedBy(tasks, _createdKey, descending: true);
      case SortingMode.dueDateIncreasing:
        return _sortedBy(tasks, _dueKey);
      case SortingMode.dueDateDecreasing:
        return _sortedBy(tasks, _dueKey, descending: true);
      case SortingMode.starredFirst:
        return _sortedBy(tasks, (t) => t.isStarred ? 0 : 1);
      case SortingMode.nonStarredFirst:
        return _sortedBy(tasks, (t) => t.isStarred ? 1 : 0);
      case SortingMode.manual:
        // Keep the original order
        return List.of(tasks);
    }
  }

  static DateTime _createdKey(Task t) =>
      DateTimeUtilsHelper.parseDateTime(t.createdAt!);

  static DateTime _dueKey(Task t) {
    final date =
        DateTimeUtilsHelper.parseDate(t.dueDate) ?? DateTime(1971, 01, 01);
    final time = DateTimeUtilsHelper.parseTime(t.dueTime!)!;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
  }

  /// Stable sort by a precomputed key (List.sort isn't guaranteed stable, so
  /// ties fall back to original position — matching the old starred-first
  /// behaviour of leaving equal tasks in list order).
  static List<Task> _sortedBy<K extends Comparable<dynamic>>(
    List<Task> tasks,
    K Function(Task) keyOf, {
    bool descending = false,
  }) {
    final keyed = List.generate(
      tasks.length,
      (i) => (task: tasks[i], key: keyOf(tasks[i]), pos: i),
      growable: false,
    );
    keyed.sort((a, b) {
      final c = descending ? b.key.compareTo(a.key) : a.key.compareTo(b.key);
      return c != 0 ? c : a.pos.compareTo(b.pos);
    });
    return [for (final e in keyed) e.task];
  }
}
