import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class SortTasksService {
  static List<Task> sortTasksByMode(
    List<Task> tasksOfThisTab,
    SortingMode mode,
  ) {
    switch (mode) {
      case SortingMode.aToz:
        tasksOfThisTab.sort((a, b) {
          String titleA = a.name;
          String titleB = b.name;
          return titleA.toLowerCase().compareTo(titleB.toLowerCase());
        });
        break;
      case SortingMode.zToa:
        tasksOfThisTab.sort((a, b) {
          String titleA = a.name;
          String titleB = b.name;
          return titleB.toLowerCase().compareTo(titleA.toLowerCase());
        });
        break;
      case SortingMode.createdDateIncreasing:
        tasksOfThisTab.sort((a, b) {
          DateTime dateA = DateTimeUtilsHelper.parseDateTime(a.createdAt!);
          DateTime dateB = DateTimeUtilsHelper.parseDateTime(b.createdAt!);
          return dateA.compareTo(dateB);
        });
        break;
      case SortingMode.createdDateDecreasing:
        tasksOfThisTab.sort((a, b) {
          DateTime dateA = DateTimeUtilsHelper.parseDateTime(a.createdAt!);
          DateTime dateB = DateTimeUtilsHelper.parseDateTime(b.createdAt!);
          return dateB.compareTo(dateA);
        });
        break;
      case SortingMode.dueDateIncreasing:
        tasksOfThisTab.sort((a, b) {
          DateTime dateA =
              DateTimeUtilsHelper.parseDate(a.dueDate) ??
              DateTime(1971, 01, 01);
          DateTime? timeA = DateTimeUtilsHelper.parseTime(a.dueTime!);
          DateTime dateB =
              DateTimeUtilsHelper.parseDate(b.dueDate) ??
              DateTime(1971, 01, 01);
          DateTime? timeB = DateTimeUtilsHelper.parseTime(b.dueTime!);
          DateTime dateTimeA = DateTime(
            dateA.year,
            dateA.month,
            dateA.day,
            timeA!.hour,
            timeA.minute,
            timeA.second,
          );
          DateTime dateTimeB = DateTime(
            dateB.year,
            dateB.month,
            dateB.day,
            timeB!.hour,
            timeB.minute,
            timeB.second,
          );
          return dateTimeA.compareTo(dateTimeB);
        });
        break;
      case SortingMode.dueDateDecreasing:
        tasksOfThisTab.sort((a, b) {
          DateTime dateA =
              DateTimeUtilsHelper.parseDate(a.dueDate) ??
              DateTime(1971, 01, 01);
          DateTime? timeA = DateTimeUtilsHelper.parseTime(a.dueTime!);
          DateTime dateB =
              DateTimeUtilsHelper.parseDate(b.dueDate) ??
              DateTime(1971, 01, 01);
          DateTime? timeB = DateTimeUtilsHelper.parseTime(b.dueTime!);
          DateTime dateTimeA = DateTime(
            dateA.year,
            dateA.month,
            dateA.day,
            timeA!.hour,
            timeA.minute,
            timeA.second,
          );
          DateTime dateTimeB = DateTime(
            dateB.year,
            dateB.month,
            dateB.day,
            timeB!.hour,
            timeB.minute,
            timeB.second,
          );
          return dateTimeB.compareTo(dateTimeA);
        });
        break;
      case SortingMode.starredFirst:
        tasksOfThisTab.sort((a, b) {
          bool isStarredA = a.isStarred;
          bool isStarredB = b.isStarred;
          if (isStarredA == isStarredB) {
            return 0;
          } else if (isStarredA && !isStarredB) {
            return -1; // A comes before B
          } else {
            return 1; // B comes before A
          }
        });
        break;
      case SortingMode.nonStarredFirst:
        tasksOfThisTab.sort((a, b) {
          bool isStarredA = a.isStarred;
          bool isStarredB = b.isStarred;
          if (isStarredA == isStarredB) {
            return 0;
          } else if (!isStarredA && isStarredB) {
            return -1; // A comes before B
          } else {
            return 1; // B comes before A
          }
        });
        break;
      case SortingMode.manual:
        // Do nothing, keep the original order
        break;
    }
    return tasksOfThisTab;
  }
}
