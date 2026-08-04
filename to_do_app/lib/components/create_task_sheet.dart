import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:to_do_app/components/ai_generation_button.dart';
import 'package:to_do_app/components/create_subtask_dialog.dart';
import 'package:to_do_app/components/edit_subtask_dialog.dart';
//import 'package:intl/intl.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
//import 'package:to_do_app/services/notification_service.dart';

class CreateTaskSheet extends StatefulWidget {
  final String buttonText;
  final bool isStarred;
  final String taskName;
  final String taskNote;
  // final TextEditingController taskNameController;
  // final TextEditingController taskNoteController;
  // final TextEditingController remainderAmountController;
  final ValueChanged<Map<String, dynamic>>? onSave;
  final List<String> repeatTypes;
  final List<String> priorityTypes;
  final List<String> remainderTypes;
  final List<String> categoryTypes;
  final List<Map<String, dynamic>>? initialSubtasks;
  //final List<List<dynamic>> toDoList;

  // only hold initial values here (immutable config)
  final DateTime? initialDueDate;
  final DateTime? initialDueTime;
  final String initialCategory;
  final String initialPriority;
  final String initialRepeatType;
  final int initialRemainderAmount;
  final String initialRemainderType;
  final String firstDayOfWeek;

  const CreateTaskSheet({
    super.key,
    required this.isStarred,
    this.buttonText = "Create Task",
    this.initialDueDate,
    this.initialDueTime,
    this.initialCategory = "None",
    this.initialPriority = "Low",
    this.initialRepeatType = "daily",
    this.initialRemainderAmount = 0,
    this.initialRemainderType = "minutes",
    this.firstDayOfWeek = "System Default",
    required this.taskName,
    required this.taskNote,
    required this.initialSubtasks,
    // required this.taskNameController,
    // required this.taskNoteController,
    // required this.remainderAmountController,
    required this.onSave,
    required this.repeatTypes,
    required this.priorityTypes,
    required this.remainderTypes,
    required this.categoryTypes,
    //required this.toDoList,
  });

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  //List<Map<String, dynamic>> _subTasks = [];

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _selectedDueDate;
  DateTime? _selectedDueTime;
  late String _selectedCategory;
  late String _selectedPriority;
  late String _selectedRepeatType;
  //late int _selectedRemainderAmount;
  late String _selectedRemainderType;
  late List<Map<String, dynamic>> _addedSubtasks = [];
  bool _isStarred = false;
  late TextEditingController taskNameController;
  late TextEditingController taskNoteController;
  late TextEditingController reminderAmountController;
  @override
  void initState() {
    super.initState();
    print(("====${widget.initialDueDate},${widget.initialDueTime}"));
    _selectedDueDate = widget.initialDueDate;
    _selectedDueTime = widget.initialDueTime;
    _selectedCategory = widget.initialCategory;
    _selectedPriority = widget.initialPriority;
    _selectedRepeatType = widget.initialRepeatType;
    //_selectedRemainderAmount = widget.initialRemainderAmount;
    _selectedRemainderType = widget.initialRemainderType;
    _addedSubtasks = widget.initialSubtasks ?? [];
    taskNameController = TextEditingController(text: widget.taskName);
    taskNoteController = TextEditingController(text: widget.taskNote);
    reminderAmountController = TextEditingController(
      text: widget.initialRemainderAmount.toString(),
    );
    if (widget.initialDueDate != null) {
      // Editing existing task: stored UTC values → local for display
      _selectedDueTime ??= DateTimeUtilsHelper.toUtcUsingLocal(
        DateTime(1970, 1, 1, 23, 59),
      );
      final combinedTime = DateTimeUtilsHelper.combineDateAndTime(
        _selectedDueDate,
        _selectedDueTime,
      );
      final localTime = DateTimeUtilsHelper.toLocalUsingTz(combinedTime);
      _selectedDueDate = localTime;
      _selectedDueTime = localTime;
    } else {
      // New task: use device local time directly — no UTC conversion needed
      _selectedDueDate = DateTime.now();
      _selectedDueTime = DateTime(1970, 1, 1, 23, 59);
    }
    _isStarred = widget.isStarred;
    print("time $_selectedDueDate  $_selectedDueTime");
  }

  @override
  void dispose() {
    // Dispose controllers if they were created here
    // widget.taskNameController.text = "";
    // widget.taskNoteController.text = "";
    // widget.remainderAmountController.text = "";
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return makeDismissible(
      context: context,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder:
            (_, controller) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        // --- drag handle ---
                        Center(
                          child: Container(
                            height: 5,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // --- title ---
                        widget.buttonText == "Add Task"
                            ? Text(
                              'Create New Task',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            )
                            : Text(
                              'Edit Task',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                        const SizedBox(height: 20),

                        // --- task name ---
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: taskNameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Task Name or Prompt Text',
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            AiGenerationButton(
                              context: context,
                              goal: taskNameController,
                              timeframe: "tomorrow",

                              onResult: (Map<String, dynamic> taskDetails) {
                                setState(() {
                                  final tasksDynamic = taskDetails['tasks'];
                                  final tasks =
                                      (tasksDynamic is List)
                                          ? tasksDynamic
                                          : <dynamic>[];

                                  if (tasks.isNotEmpty) {
                                    final first =
                                        tasks[0] as Map<String, dynamic>? ?? {};

                                    // Task name & note
                                    taskNameController.text =
                                        (first['task_name'] ??
                                                first['taskName'])
                                            ?.toString() ??
                                        taskNameController.text;
                                    taskNoteController.text =
                                        (first['task_note'])?.toString() ??
                                        taskNoteController.text;

                                    // dueDate (accept String or DateTime)
                                    final dueDateRaw = first['due_date'];
                                    if (dueDateRaw != null) {
                                      if (dueDateRaw is String) {
                                        final parsed =
                                            DateTimeUtilsHelper.parseDate(
                                              dueDateRaw,
                                            );
                                        if (parsed != null)
                                          _selectedDueDate = parsed;
                                      } else if (dueDateRaw is DateTime) {
                                        _selectedDueDate = dueDateRaw;
                                      }
                                    }

                                    // dueTime (accept String or DateTime)
                                    final dueTimeRaw = first['due_time'];
                                    if (dueTimeRaw != null) {
                                      if (dueTimeRaw is String) {
                                        final parsed =
                                            DateTimeUtilsHelper.parseTime(
                                              dueTimeRaw,
                                            );

                                        if (parsed != null)
                                          _selectedDueTime = parsed;
                                      } else if (dueTimeRaw is DateTime) {
                                        _selectedDueTime = dueTimeRaw;
                                      }
                                    }
                                    // starred
                                    _isStarred =
                                        (first['isStarred'] == true) ||
                                        (first['is_starred'] == true) ||
                                        _isStarred;

                                    // category, priority, repeatType
                                    _selectedCategory =
                                        first['category']?.toString() ??
                                        _selectedCategory;
                                    _selectedPriority =
                                        first['priority']?.toString() ??
                                        _selectedPriority;
                                    _selectedRepeatType =
                                        first['repeat_type']?.toString() ??
                                        _selectedRepeatType;

                                    // remainder amount & type
                                    final remAmount = first['reminder_amount'];
                                    if (remAmount != null) {
                                      reminderAmountController.text =
                                          remAmount.toString();
                                    }
                                    _selectedRemainderType =
                                        first['reminder_type']?.toString() ??
                                        _selectedRemainderType;
                                    //_addedSubtasks = first['subtasks'] ?? [];
                                    for (var subTask in first['subtasks']) {
                                      _addedSubtasks.add({
                                        "name": subTask['name'],
                                        "dueDate":
                                            DateTimeUtilsHelper.parseDate(
                                              subTask['due_date'],
                                            ),
                                        "dueTime":
                                            DateTimeUtilsHelper.parseTime(
                                              subTask['due_time'],
                                            ),
                                        "completed": false,
                                      });
                                    }
                                    print("=====$_addedSubtasks");
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // --- task note ---
                        TextField(
                          controller: taskNoteController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Task Note',
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          "Add sub tasks :",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _addedSubtasks.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = _addedSubtasks.removeAt(
                                    oldIndex,
                                  );
                                  _addedSubtasks.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final sub = _addedSubtasks[index];
                                return GestureDetector(
                                  key: ValueKey(
                                    sub['name'] + index.toString(),
                                  ), // Required for reorder
                                  onTap:
                                      () => _showEditSubTaskDialog(
                                        context,
                                        index,
                                      ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.drag_handle,
                                            color: Colors.grey,
                                          ),
                                          Checkbox(
                                            value: sub['completed'],
                                            onChanged: (val) {
                                              setState(() {
                                                _addedSubtasks[index]['completed'] =
                                                    val!;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      title: Text(
                                        sub['name'],
                                        style: TextStyle(
                                          decoration:
                                              sub['completed']
                                                  ? TextDecoration
                                                      .lineThrough // 👈 add strikethrough if condition is true
                                                  : TextDecoration.none,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${DateTimeUtilsHelper.formatDate(sub['dueDate'] is String ? DateTime.tryParse(sub['dueDate']) : sub['dueDate'] as DateTime?)}  "
                                        "${DateTimeUtilsHelper.formatTime(sub['dueTime'] is String ? DateTime.tryParse(sub['dueTime']) : sub['dueTime'] as DateTime?, format: 'hh:mm a')}",
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          setState(
                                            () =>
                                                _addedSubtasks.removeAt(index),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            TextButton.icon(
                              onPressed: () => _showAddSubTaskDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text("Add Subtask"),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // --- calendar ---
                        TableCalendar(
                          startingDayOfWeek:
                              DateTimeUtilsHelper.startingDayOfWeekFromSetting(
                                widget.firstDayOfWeek,
                              ),
                          focusedDay: _selectedDueDate ?? DateTime.now(),
                          firstDay: DateTime.utc(1969, 1, 1),
                          lastDay: DateTime.utc(2100, 1, 1),
                          selectedDayPredicate:
                              (day) => isSameDay(day, _selectedDueDate),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() => _selectedDueDate = selectedDay);
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          calendarFormat: _calendarFormat,
                          calendarStyle: CalendarStyle(
                            selectedDecoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- time picker ---
                        ExpansionTile(
                          title: Row(
                            children: [
                              const Icon(Icons.access_time),
                              const SizedBox(width: 10),
                              Text(
                                "Set Time",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                            ],
                          ),
                          subtitle:
                              _selectedDueTime != null
                                  ? Text(
                                    DateTimeUtilsHelper.formatTime(
                                      _selectedDueTime,
                                      format: "hh:mm a",
                                    ).toString(),
                                  ) //Text(DateFormat.jm().format(_selectedDueTime!))
                                  : null,
                          children: [
                            ListTile(
                              title: Text(
                                "Pick a time",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                              onTap: () async {
                                // If no time selected yet, default to now
                                final initialTime =
                                    _selectedDueTime != null
                                        ? TimeOfDay(
                                          hour: _selectedDueTime!.hour,
                                          minute: _selectedDueTime!.minute,
                                        )
                                        : TimeOfDay.now();
                                print(
                                  "----------initialTime ${_selectedDueTime!.hour},${_selectedDueTime!.minute}",
                                );
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: initialTime,
                                );
                                if (picked != null) {
                                  setState(() {
                                    final now = DateTime.now();
                                    _selectedDueTime = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text("Star this task : "),
                            Checkbox(
                              value: _isStarred,
                              onChanged: (bool? value) {
                                _isStarred = !_isStarred;
                                print("_isStarred $_isStarred");
                                setState(() {});
                                //return isStarred;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        //--- remider ---
                        Row(
                          children: [
                            Text(
                              "Remind me before : ",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                            SizedBox(width: 20),
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                controller: reminderAmountController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: '',
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: DropdownButton<String>(
                                value: _selectedRemainderType,
                                items:
                                    widget.remainderTypes.map((String option) {
                                      return DropdownMenuItem<String>(
                                        value: option,
                                        child: Text(option),
                                      );
                                    }).toList(),
                                onChanged: (newValue) {
                                  if (newValue == null) return;
                                  setState(
                                    () => _selectedRemainderType = newValue,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // --- repeat type ---
                        Row(
                          children: [
                            Text(
                              "Repeat this task : ",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: DropdownButton<String>(
                                value: _selectedRepeatType,
                                items:
                                    widget.repeatTypes.map((String option) {
                                      return DropdownMenuItem<String>(
                                        value: option,
                                        child: Text(option),
                                      );
                                    }).toList(),
                                onChanged: (newValue) {
                                  if (newValue == null) return;
                                  setState(
                                    () => _selectedRepeatType = newValue,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- priority ---
                        Row(
                          children: [
                            Text(
                              "Task priority : ",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: DropdownButton<String>(
                                value: _selectedPriority,
                                items:
                                    widget.priorityTypes.map((String option) {
                                      return DropdownMenuItem<String>(
                                        value: option,
                                        child: Text(option),
                                      );
                                    }).toList(),
                                onChanged: (newValue) {
                                  if (newValue == null) return;
                                  setState(() => _selectedPriority = newValue);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // --- category ---
                        Row(
                          children: [
                            Text(
                              "Task category : ",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: DropdownButton<String>(
                                borderRadius: BorderRadius.circular(20),
                                value: _selectedCategory,
                                items:
                                    widget.categoryTypes.map((String option) {
                                      return DropdownMenuItem<String>(
                                        value: option,
                                        child: Text(option),
                                      );
                                    }).toList(),
                                onChanged: (newValue) {
                                  if (newValue == null) return;
                                  setState(() => _selectedCategory = newValue);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // --- save button ---
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          final combined =
                              DateTimeUtilsHelper.combineDateAndTime(
                                _selectedDueDate,

                                _selectedDueTime,
                              );
                          final utcTime = DateTimeUtilsHelper.toUtcUsingLocal(
                            combined,
                          );

                          final taskData = {
                            'createdAt': DateTime.now().toUtc().toString(),
                            'isStarred': _isStarred.toString(),
                            'taskName': taskNameController.text,
                            'taskNote': taskNoteController.text,
                            'dueDate': DateTimeUtilsHelper.formatDate(utcTime),
                            'dueTime': DateTimeUtilsHelper.formatTime(utcTime),
                            'taskCategory': _selectedCategory,
                            'taskPriority': _selectedPriority,
                            'repeatType': _selectedRepeatType,
                            'remainderAmount':
                                int.tryParse(reminderAmountController.text) ??
                                0,
                            'remainderType': _selectedRemainderType,
                            'subTasks': _addedSubtasks,
                          };

                          widget.onSave?.call(taskData);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Navigator.of(context).pop();
                          });
                        },

                        child: Text(widget.buttonText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget makeDismissible({
    required Widget child,
    required BuildContext context,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).pop(),
    child: GestureDetector(onTap: () {}, child: child),
  );

  Future<void> _showAddSubTaskDialog(BuildContext context) async {
    // final TextEditingController nameController = TextEditingController();
    // DateTime? subDueDate;
    // DateTime? subDueTime;

    await showDialog(
      context: context,
      builder: (context) {
        return AddSubTaskDialog(
          dueDate: _selectedDueDate ?? DateTime.now(),
          dueTime: _selectedDueTime ?? DateTime(1970, 1, 1, 23, 59, 59),
          onAdd: (subtask) {
            setState(() {
              _addedSubtasks.add(subtask);
            });
          },
        );
      },
    );
  }

  Future<void> _showEditSubTaskDialog(BuildContext context, int index) async {
    // Get the subtask being edited
    final subtask = _addedSubtasks[index];

    // final TextEditingController nameController = TextEditingController(
    //   text: subtask["name"],
    // );

    // DateTime? subDueDate = subtask["dueDate"];
    // DateTime? subDueTime = subtask["dueTime"];

    await showDialog(
      context: context,
      builder: (context) {
        return EditSubTaskDialog(
          subtask: subtask,
          onSave: (newSubtask) {
            setState(() {
              _addedSubtasks[index] = newSubtask;
            });
          },
        );
      },
    );
  }
}
