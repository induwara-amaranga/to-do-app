import 'dart:collection';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class GroupTasksService {
  static Map<String, List<Task>> groupTasksByMode(
    List<Task> tasksOfThisTab,
    GroupingMode mode,
    bool isCompleted,
  ) {
    final DateTime now = DateTime.now();
    switch (mode) {
      case GroupingMode.Default:
        if (isCompleted) {
          Map<String, List<Task>> grouped = {
            "today": [],
            "upcoming": [],
            "past": [],
          };

          for (var task in tasksOfThisTab) {
            DateTime taskDate =
                DateTimeUtilsHelper.parseDate(task.dueDate) ??
                DateTime(1971, 01, 01);

            if (taskDate.year == now.year &&
                taskDate.month == now.month &&
                taskDate.day == now.day) {
              grouped["today"]!.add(task);
            } else if (taskDate.isAfter(now)) {
              grouped["upcoming"]!.add(task);
            } else {
              grouped["past"]!.add(task);
            }
          }
          return grouped;
        } else {
          Map<String, List<Task>> grouped = {
            "today": [],
            "upcoming": [],
            "missed": [],
          };

          for (var task in tasksOfThisTab) {
            DateTime taskDate =
                DateTimeUtilsHelper.parseDate(task.dueDate) ??
                DateTime(1971, 01, 01);

            if (taskDate.year == now.year &&
                taskDate.month == now.month &&
                taskDate.day == now.day) {
              grouped["today"]!.add(task);
            } else if (taskDate.isAfter(now)) {
              grouped["upcoming"]!.add(task);
            } else {
              grouped["missed"]!.add(task);
            }
          }
          return grouped;
        }
      case GroupingMode.year:
        Map<String, List<Task>> grouped = {};

        for (var task in tasksOfThisTab) {
          DateTime taskDate =
              DateTimeUtilsHelper.parseDate(task.dueDate) ??
              DateTime(1971, 01, 01);
          String year = taskDate.year.toString();
          if (year != "1970") {
            if (!grouped.containsKey(year)) {
              grouped[year] = [];
            }
            grouped[year]!.add(task);
          } else {
            if (!grouped.containsKey("No Date")) {
              grouped["No Date"] = [];
            }
            grouped["No Date"]!.add(task);
          }
        }
        grouped = SplayTreeMap<String, List<Task>>.from(grouped, (a, b) {
          if (a == "No Date") return 1; // keep "No Date" at the end
          if (b == "No Date") return -1;
          return a.compareTo(b); // ascending order
        });

        return grouped;
      case GroupingMode.month:
        Map<String, List<Task>> grouped = {};
        for (var task in tasksOfThisTab) {
          DateTime taskDate =
              DateTimeUtilsHelper.parseDate(task.dueDate) ??
              DateTime(1971, 01, 01);
          String month = DateTimeUtilsHelper.formatDate(
            taskDate,
            format: "yyyy-MM",
          );
          if (month != "1970-01") {
            if (!grouped.containsKey(month)) {
              grouped[month] = [];
            }
            grouped[month]!.add(task);
          } else {
            if (!grouped.containsKey("No Date")) {
              grouped["No Date"] = [];
            }
            grouped["No Date"]!.add(task);
          }
        }
        grouped = SplayTreeMap<String, List<Task>>.from(grouped, (a, b) {
          if (a == "No Date") return 1; // keep "No Date" at the end
          if (b == "No Date") return -1;
          return a.compareTo(b); // ascending order
        });
        return grouped;
      case GroupingMode.day:
        Map<String, List<Task>> grouped = {};
        for (var task in tasksOfThisTab) {
          DateTime taskDate =
              DateTimeUtilsHelper.parseDate(task.dueDate) ??
              DateTime(1971, 01, 01);
          String day = DateTimeUtilsHelper.formatDate(
            taskDate,
            format: "yyyy-MM-dd",
          );
          if (day != "1970-01-01") {
            if (!grouped.containsKey(day)) {
              grouped[day] = [];
            }
            grouped[day]!.add(task);
          } else {
            if (!grouped.containsKey("No Date")) {
              grouped["No Date"] = [];
            }
            grouped["No Date"]!.add(task);
          }
        }
        //sorts the map by key (date)
        grouped = SplayTreeMap<String, List<Task>>.from(grouped, (a, b) {
          if (a == "No Date") return 1; // keep "No Date" at the end
          if (b == "No Date") return -1;
          return a.compareTo(b); // ascending order
        });
        return grouped;
    }
  }
}
