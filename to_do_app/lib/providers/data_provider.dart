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

  int _taskRevision = 0;

  /// Bumped whenever the task list changes. Widgets that only need to react
  /// to task changes should `select` this (see TaskPage) so they rebuild on a
  /// toggle, edit, delete or reorder without dragging the rest of the screen
  /// (drawer, FAB, nav bar) along.
  int get taskRevision => _taskRevision;

  /// Call after mutating `db.toDoList` outside the helpers below.
  void markTasksChanged() {
    _taskRevision++;
    // Also invalidates anything cached against the database itself.
    db.dataRevision++;
    notifyListeners();
  }

  List<Task> get tasks => db.toDoList;
  List<CalendarEvent> get localEvents => db.localCalTasks;
  List<CalendarEvent> get googleEvents => db.googleCalTasks;
  List<CalendarEvent> get outlookEvents => db.outlookCalTasks;
  List<String> get categories => db.categories;

  // ── Mutations ─────────────────────────────────────────────────────────
  Future<void> persistAll() async {
    await db.updateDataBase();
    markTasksChanged();
  }

  Future<void> persistToDoList() async {
    await db.saveToDoList();
    markTasksChanged();
  }

  Future<void> persistCategories() async {
    db.saveCategories();
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await db.appendTask(task);
    markTasksChanged();
  }

  Future<void> deleteTaskAt(int index) async {
    await db.removeTaskAt(index);
    markTasksChanged();
  }

  Future<void> reorderTasks(int from, int to) async {
    await db.moveTask(from, to);
    markTasksChanged();
  }
}
