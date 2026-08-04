import 'package:flutter/foundation.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/task.dart';

/// Wraps [ToDoDataBase] in a [ChangeNotifier] so widgets can react to
/// data changes via Provider instead of receiving `db` as a constructor arg.
///
/// Exposes the typed lists directly (same objects [db] holds, not copies) so
/// mutating a returned [Task]/[CalendarEvent] and calling the matching
/// `persist*` method round-trips correctly.
class DataProvider extends ChangeNotifier {
  final ToDoDataBase db;
  DataProvider(this.db);

  List<Task> get tasks => db.toDoList;
  List<CalendarEvent> get localEvents => db.localCalTasks;
  List<CalendarEvent> get googleEvents => db.googleCalTasks;
  List<CalendarEvent> get outlookEvents => db.outlookCalTasks;
  List<String> get categories => db.categories;

  // ── Mutations ─────────────────────────────────────────────────────────
  Future<void> persistAll() async {
    await db.updateDataBase();
    notifyListeners();
  }

  Future<void> persistToDoList() async {
    await db.saveToDoList();
    notifyListeners();
  }

  Future<void> persistCategories() async {
    db.saveCategories();
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    db.toDoList.add(task);
    await persistToDoList();
  }

  Future<void> deleteTaskAt(int index) async {
    db.toDoList.removeAt(index);
    await persistToDoList();
  }

  Future<void> reorderTasks(int from, int to) async {
    final task = db.toDoList.removeAt(from);
    db.toDoList.insert(to, task);
    await persistToDoList();
  }
}
