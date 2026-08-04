import 'package:flutter/material.dart';
//import 'package:googleapis/cloudsearch/v1.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:to_do_app/components/create_task_sheet.dart';
import 'package:to_do_app/components/sync_tile.dart';
import 'package:to_do_app/components/task_page_bottom_nav_bar.dart';
import 'package:to_do_app/components/task_tile.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/types.dart';
import 'package:to_do_app/services/local_calendar_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/services/repeat_task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class CalendarPage extends StatefulWidget {
  final ToDoDataBase db;
  const CalendarPage({super.key, required this.db});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat calendarFormat = CalendarFormat.month;
  DateTime focusedDay = DateTime.now();
  DateTime firstDay = DateTime.utc(2000, 01, 01);
  DateTime lastDay = DateTime.utc(2100, 12, 31);
  DateTime selectedDay = DateTime.now();
  List<Task> toDoList = [];
  List<Task> tasksForSelectedDay = [];
  List<CalendarEvent> calTasksForSelectedDay = [];
  late final ToDoDataBase db;

  bool _isStarred = false;

  void checkBoxChanged(bool? value, int index) {
    print("Checkbox at index $index changed to $value");

    if (value != null) {
      if (value) {
        db.toDoList[index].completedAt = DateTime.now().toUtc().toString();
      } else {
        db.toDoList[index].completedAt = "none";
      }
    }

    // Step 1: toggle checkbox
    setState(() {
      toDoList[index].completed = !toDoList[index].completed;
    });

    // Step 2: handle repeating logic OUTSIDE setState
    if (value == true && toDoList[index].repeatType != "none") {
      RepeatTask.createNextRepeatTask(context, index, db);
    }

    // Step 3: refresh lists & persist data
    setState(() {
      toDoList = toDoList;
      //hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
    });

    db.updateDataBase();
  }

  void saveNewTask(Map<String, dynamic> taskDetails) async {
    final selectedRemainderType = taskDetails['repeatType']; //7
    final selectedRemainderAmount = taskDetails['remainderAmount'];
    String id = uuid.v4();
    final List<Map<String, dynamic>> subTaskMaps =
        (taskDetails['subTasks'] as List<Map<String, dynamic>>?) ?? [];
    final Task task = Task(
      name: taskDetails['taskName'],
      completed: false,
      note: taskDetails['taskNote'],
      dueDate: taskDetails['dueDate'],
      dueTime: taskDetails['dueTime'],
      category: taskDetails['taskCategory'],
      priority: taskDetails['taskPriority'],
      repeatType: taskDetails['repeatType'],
      reminderAmount: taskDetails['remainderAmount'],
      reminderType: taskDetails['remainderType'],
      isStarred: taskDetails['isStarred'],
      createdAt: taskDetails['createdAt'],
      id: id,
      subtasks: subTaskMaps.map(SubTask.fromMap).toList(),
      localCalendarId: "",
      localEventId: "",
      remoteEventIds: ["", "", ""],
      source: "manual",
      completedAt: "none",
      notificationIds: [],
    );
    setState(() {
      print("adding tasks $taskDetails");
      db.toDoList.add(task);
    });

    // ⏰ Schedule notification if remainder is set
    if (selectedRemainderAmount >= 0 && selectedRemainderType != "none") {
      await NotificationService.scheduleInitialRemainderForTask(
        id,
        context,
        taskDetails,
        db,
        toDoList.length - 1,
      );
    }
    print("A F T E R   N E W   T A S K-----------------------------");
    print(db.toDoList);
    toDoList = db.toDoList;
    db.updateDataBase();
    if (db.syncToCalendars["local"] != "none") {
      print("🔄");
      LocalCalendarService.addEvent(db.syncToCalendars["local"], task);
    }
  }

  void deleteTask(int index) async {
    await LocalCalendarService.deleteEvent(
      db.toDoList[index].remoteEventIds[0],
      db.syncToCalendars["local"],
    );
    for (int id in db.toDoList[index].notificationIds) {
      print("calling to id $id for edited task");
      await NotificationService.cancelNotification(id);
    }
    setState(() {
      db.toDoList.removeAt(index);
    });
    toDoList = db.toDoList;
    db.updateDataBase();
    if (db.syncToCalendars["local"] != "none" &&
        db.toDoList[index].remoteEventIds[0] != "") {
      print("🔄");
    }
  }

  void editTask(int index, Map<String, dynamic> taskDetails) async {
    String id = uuid.v4();
    setState(() {
      final task = db.toDoList[index];
      task.name = taskDetails['taskName'];
      task.note = taskDetails['taskNote'];
      task.dueDate = taskDetails['dueDate'];
      task.dueTime = taskDetails['dueTime'];
      task.category = taskDetails['taskCategory'];
      task.priority = taskDetails['taskPriority'];
      task.repeatType = taskDetails['repeatType'];
      task.reminderAmount = taskDetails['remainderAmount'];
      task.reminderType = taskDetails['remainderType'];
      task.isStarred = taskDetails['isStarred'];
      task.createdAt = taskDetails['createdAt'];
      final List<Map<String, dynamic>> subTaskMaps =
          (taskDetails['subTasks'] as List<Map<String, dynamic>>?) ?? [];
      task.subtasks = subTaskMaps.map(SubTask.fromMap).toList();
    });

    for (int id in db.toDoList[index].notificationIds) {
      print("calling to id $id for edited task");
      await NotificationService.cancelNotification(id);
    }

    // ⏰ Schedule notification if remainder is set
    if (taskDetails['remainderAmount'] >= 0 &&
        taskDetails['remainderType'] != "none") {
      await NotificationService.scheduleInitialRemainderForTask(
        id,
        context,
        taskDetails,
        db,
        index,
      );
      // DateTime? dueDate = DateTimeUtilsHelper.parseDate(taskDetails['dueDate']);
      // DateTime? dueTime = DateTimeUtilsHelper.parseTime(taskDetails['dueTime']);
      // DateTime remainderDateTime = NotificationService.remainderDateTime(
      //   dueDate!,
      //   dueTime!,
      //   //taskDetails['dueTime'],
      //   taskDetails['remainderType'],
      //   taskDetails['remainderAmount'],
      // );
      // try {
      //   NotificationService.sheduledTimeNotification(
      //     priority: taskDetails['taskPriority'],
      //     context: context,
      //     id: id.hashCode,
      //     title: "teask remainder" + " ",
      //     body: _taskNameController.text,
      //     year: remainderDateTime.year,
      //     month: remainderDateTime.month,
      //     day: remainderDateTime.day,
      //     hour: remainderDateTime.hour,
      //     minutes: remainderDateTime.minute,
      //     payload: [
      //       id,
      //       taskDetails['taskPriority'],
      //       DateTimeUtilsHelper.combineDateAndTime(dueDate, dueTime),
      //       "teask remainder",
      //       _taskNameController.text,
      //     ],
      //   );
      // } catch (e) {
      //   print("shedule error form task page => $e");
      // }
    }
    print("Edited task at index $index: ${db.toDoList[index]}");
    toDoList = db.toDoList;
    // categorizedToDOTasks =
    //     _taskCategoryTabs().map((tab) {
    //       return _buildTasksForTab(tab.text, grouping, sorting, query);
    //     }).toList();
    //hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
    if (db.syncToCalendars["local"] != "none") {
      print("🔄");
      LocalCalendarService.addEvent(
        db.syncToCalendars["local"],
        db.toDoList[index],
      );
    }
    db.updateDataBase();
  }

  List<CalendarEvent> _getCalTasksForDay(DateTime day) {
    return [
      ...db.localCalTasks.where((t) => _isCalEventOnDay(t, day)),
      ...db.googleCalTasks.where((t) => _isCalEventOnDay(t, day)),
      ...db.outlookCalTasks.where((t) => _isCalEventOnDay(t, day)),
    ];
  }

  bool _isOnDay({
    required String? dueDate,
    required String? dueTime,
    required bool completed,
    required String? repeatType,
    required DateTime day,
  }) {
    if (dueDate == null || dueDate == "0000-00-00") return false;

    final DateTime dueLocal = DateTimeUtilsHelper.toLocalUsingTz(
      DateTimeUtilsHelper.combineDateAndTimeFromStrings(
        dueDate,
        dueTime ?? "00:00",
      ),
    );

    final sel = DateTime(day.year, day.month, day.day);
    final due = DateTime(dueLocal.year, dueLocal.month, dueLocal.day);

    // Always show on the exact due date
    if (sel == due) return true;

    // Completed tasks and non-repeating tasks only show on their due date
    if (completed || repeatType == null || repeatType == "none") return false;

    // Repeating incomplete tasks: selected day must be after the due date
    if (sel.isBefore(due)) return false;

    switch (repeatType) {
      case 'daily':
        return true;
      case 'weekly':
        return sel.weekday == due.weekday;
      case 'monthly':
        return sel.day == due.day;
      case 'yearly':
        return sel.month == due.month && sel.day == due.day;
      default:
        return false;
    }
  }

  bool _isTaskOnDay(Task task, DateTime day) => _isOnDay(
    dueDate: task.dueDate,
    dueTime: task.dueTime,
    completed: task.completed,
    repeatType: task.repeatType,
    day: day,
  );

  bool _isCalEventOnDay(CalendarEvent task, DateTime day) => _isOnDay(
    dueDate: task.dueDate,
    dueTime: task.dueTime,
    completed: task.completed,
    repeatType: task.repeatType,
    day: day,
  );

  @override
  void initState() {
    super.initState();
    db = widget.db;
    toDoList = widget.db.toDoList;
    tasksForSelectedDay =
        toDoList.where((task) => _isTaskOnDay(task, selectedDay)).toList();
    calTasksForSelectedDay = _getCalTasksForDay(selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    focusedDay = DateTime.now();
    return Scaffold(
      bottomNavigationBar: TaskBottomNavBar(current: 0),
      appBar: AppBar(
        title: Text(
          '         Calendar',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TableCalendar(
              startingDayOfWeek:
                  DateTimeUtilsHelper.startingDayOfWeekFromSetting(
                    db.settings.firstDayOfWeek,
                  ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                //formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  //fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, size: 28),
                rightChevronIcon: Icon(Icons.chevron_right, size: 28),
                headerPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',

                CalendarFormat.week: 'Week',
              },
              calendarFormat: calendarFormat,
              onFormatChanged: (format) {
                setState(() {
                  calendarFormat = format;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),

              focusedDay: focusedDay,
              firstDay: firstDay,
              lastDay: lastDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  this.selectedDay = selectedDay;
                  this.focusedDay = focusedDay;
                  tasksForSelectedDay =
                      toDoList
                          .where((task) => _isTaskOnDay(task, selectedDay))
                          .toList();
                  calTasksForSelectedDay = _getCalTasksForDay(selectedDay);
                });
              },
              selectedDayPredicate: (day) {
                return isSameDay(selectedDay, day);
              },
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (tasksForSelectedDay.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Tasks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ...tasksForSelectedDay.map((task) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: TaskTile(
                      source: task.source,
                      disableCompleted: () {
                        setState(() {});
                      },
                      key: ValueKey(
                        '${task.name}_${task.id}_${task.toString()}',
                      ),
                      initialSubtasks:
                          task.subtasks.map((s) => s.toMap()).toList(),
                      index: toDoList.indexOf(task),
                      isStarred: task.isStarred,
                      taskName: task.name,
                      taskCompleted: task.completed,
                      taskNote: task.note ?? '',
                      dueDate: DateTimeUtilsHelper.parseDate(task.dueDate),
                      dueTime:
                          task.dueTime != "00:00"
                              ? DateTimeUtilsHelper.parseTime(task.dueTime!)
                              : null,
                      taskCategory: task.category,
                      taskPriority: task.priority,
                      repeatType: task.repeatType!,
                      remainderAmount: task.reminderAmount,
                      remainderType: task.reminderType!,
                      onChanged:
                          (index, value) => checkBoxChanged(value, index),
                      deleteFunction:
                          (context) => deleteTask(toDoList.indexOf(task)),
                      onEdit:
                          (index, taskDetails) => editTask(index, taskDetails),
                      repeatTypes: repeatTypes,
                      priorityTypes: priorityTypes,
                      remainderTypes: remainderTypes,
                      categoryTypes: widget.db.categories,
                      playCompletionTone: db.settings.completionTone,
                      playCompletionAnimation: db.settings.completionAnimation,
                      settings: db.settings,
                    ),
                  );
                }),
                if (calTasksForSelectedDay.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Calendar Events ${calTasksForSelectedDay.length > 1 ? "(${calTasksForSelectedDay.length})" : ""}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ...calTasksForSelectedDay.map(
                  (task) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: SyncTile(task: task, settings: db.settings),
                  ),
                ),
              ],
            ),
          ),
          //SizedBox(height: 30),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
        ),
        child: FloatingActionButton(
          heroTag: "Add_Task",
          onPressed:
              () => showModalBottomSheet(
                isScrollControlled: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                backgroundColor: Colors.transparent,
                context: context,
                builder:
                    (context) => CreateTaskSheet(
                      isStarred: _isStarred,
                      taskName: "",
                      taskNote: "",
                      initialSubtasks: [],
                      buttonText: "Add Task",

                      onSave: (taskDetails) {
                        // setState(() {
                        //   _selectedDueDate = taskDetails['dueDate'];
                        //   _selectedDueTime = taskDetails['dueTime'];
                        //   _selectedCategory = taskDetails['taskCategory'];
                        //   _selectedPriority = taskDetails['taskPriority'];
                        //   _selectedRepeatType = taskDetails['repeatType'];
                        //   _selectedRemainderAmount =
                        //       taskDetails['remainderAmount'];
                        //   _selectedRemainderType =
                        //       taskDetails['remainderType'];
                        //   _addedSubtasks = taskDetails['subTasks'] ?? [];
                        //   _isStarred = taskDetails['isStarred'];
                        // });
                        print("New task details: $taskDetails");
                        saveNewTask(taskDetails);
                      },
                      repeatTypes: repeatTypes,
                      priorityTypes: priorityTypes,
                      remainderTypes: remainderTypes,
                      categoryTypes: db.categories,
                      initialCategory: db.settings.defaultCategory,
                      initialDueDate:
                          DateTimeUtilsHelper.initialDueDateFromSetting(
                            db.settings.defaultDueDate,
                          ),
                      initialRemainderAmount:
                          int.tryParse(db.settings.reminderTime) ?? 0,
                      initialRemainderType: db.settings.reminderTypeNormalized,
                      firstDayOfWeek: db.settings.firstDayOfWeek,
                    ),
              ),
          child: const Icon(Icons.add_rounded),
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
