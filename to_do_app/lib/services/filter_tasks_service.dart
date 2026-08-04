import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart'; // lib == to_do_app
import 'package:table_calendar/table_calendar.dart';

class FilterTasksService {
  static List<Task> filterTasksByCategory(
    List<Task> toDoList,
    Map<String, dynamic>? filterData,
  ) {
    List<Task> filteredTasks =
        toDoList.where((task) {
          DateTime now = DateTime.now().toUtc();

          DateTime? taskDate = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(
            DateTimeUtilsHelper.combineDateAndTime(
              DateTimeUtilsHelper.parseDate(task.dueDate),
              DateTimeUtilsHelper.parseTime(task.dueTime!),
            ),
          );

          bool isCategoryMatched(Task task, Map<String, dynamic>? filterData) {
            if ((filterData!["categories"].contains(task.category)) ||
                (filterData!["categories"].contains(task.priority)) ||
                (filterData!["categories"].isEmpty) ||
                (filterData!["categories"].contains("Completed") &&
                    task.completed == true) ||
                (filterData!["categories"].contains("Pending") &&
                    (task.completed == false) &&
                    (taskDate.isAfter(now) ||
                        (taskDate.isAtSameMomentAs(
                              DateTime(now.year, now.month, now.day),
                            ) &&
                            (taskDate == null ||
                                (taskDate.hour > now.hour ||
                                    (taskDate.hour == now.hour &&
                                        taskDate.minute > now.minute)))))) ||
                (filterData!["categories"].contains("Missed") &&
                    (task.completed == false) &&
                    (taskDate.isBefore(now) ||
                        (taskDate.isAtSameMomentAs(
                              DateTime(now.year, now.month, now.day),
                            ) &&
                            (taskDate != null &&
                                (taskDate.hour < now.hour ||
                                    (taskDate.hour == now.hour &&
                                        taskDate.minute < now.minute))))))) {
              return true;
            } else {
              return false;
            }
          }

          if ((filterData!["selectedDueDates"].isEmpty)) {
            if (isCategoryMatched(task, filterData)) {
              return true;
            }

            return false;
          } else if (!isSameDay(taskDate, DateTime(1970, 01, 01))) {
            for (DateTime date in filterData!["selectedDueDates"]) {
              date = date.toUtc();
              if ((filterData!["selectedFilter"] == "Selected_dates")) {
                // Ignore invalid dates for dueDate filter
                if (!isSameDay(
                      DateTime.utc(date.year, date.month, date.day),
                      taskDate,
                    ) ||
                    !isCategoryMatched(task, filterData)) {
                  return false;
                }
              } else if ((filterData!["selectedFilter"] == "Before")) {
                if (!taskDate.isBefore(
                      DateTime.utc(date.year, date.month, date.day),
                    ) ||
                    !isCategoryMatched(task, filterData)) {
                  return false;
                }
              } else if ((filterData!["selectedFilter"] == "After")) {
                if (!taskDate.isAfter(
                      DateTime.utc(date.year, date.month, date.day),
                    ) ||
                    !isCategoryMatched(task, filterData)) {
                  return false;
                }
              }

              return true;
            }
          }

          return false;
        }).toList();
    return filteredTasks;
  }
}
