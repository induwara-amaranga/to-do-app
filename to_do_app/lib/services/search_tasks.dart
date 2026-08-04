import 'package:to_do_app/models/task.dart';

class SearchTasks {
  static List<Task> searchByQuery(String searchQuery, List<Task> tasksList) {
    if (searchQuery.isNotEmpty) {
      tasksList =
          tasksList.where((task) {
            final name = task.name.toLowerCase();
            final note = (task.note ?? "").toLowerCase();
            return name.contains(searchQuery) || note.contains(searchQuery);
          }).toList();
    }
    return tasksList;
  }
}
