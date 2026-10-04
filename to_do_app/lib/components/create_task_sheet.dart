import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:to_do_app/components/ai_generation_button.dart';
import 'package:to_do_app/components/app_toggle.dart';
import 'package:to_do_app/components/create_subtask_dialog.dart';
import 'package:to_do_app/components/edit_subtask_dialog.dart';
import 'package:to_do_app/components/form_controls.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class CreateTaskSheet extends StatefulWidget {
  final String buttonText;
  final bool isStarred;
  final String taskName;
  final String taskNote;
  final ValueChanged<Map<String, dynamic>>? onSave;
  final List<String> repeatTypes;
  final List<String> priorityTypes;
  final List<String> remainderTypes;
  final List<String> categoryTypes;
  final List<Map<String, dynamic>>? initialSubtasks;

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
    required this.onSave,
    required this.repeatTypes,
    required this.priorityTypes,
    required this.remainderTypes,
    required this.categoryTypes,
  });

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _selectedDueDate;
  DateTime? _selectedDueTime;
  late String _selectedCategory;
  late String _selectedPriority;
  late String _selectedRepeatType;
  late String _selectedRemainderType;
  late List<Map<String, dynamic>> _addedSubtasks = [];
  bool _isStarred = false;
  late TextEditingController taskNameController;
  late TextEditingController taskNoteController;
  late TextEditingController reminderAmountController;

  @override
  void initState() {
    super.initState();
    _selectedDueDate = widget.initialDueDate;
    _selectedDueTime = widget.initialDueTime;
    _selectedCategory = widget.initialCategory;
    _selectedPriority = widget.initialPriority;
    _selectedRepeatType = widget.initialRepeatType;
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
  }

  @override
  void dispose() {
    taskNameController.dispose();
    taskNoteController.dispose();
    reminderAmountController.dispose();
    super.dispose();
  }

  // ── AI result → form fields ───────────────────────────────────────────────

  void _applyAiResult(Map<String, dynamic> taskDetails) {
    setState(() {
      final tasksDynamic = taskDetails['tasks'];
      final tasks = (tasksDynamic is List) ? tasksDynamic : <dynamic>[];

      if (tasks.isNotEmpty) {
        final first = tasks[0] as Map<String, dynamic>? ?? {};

        // Task name & note
        taskNameController.text =
            (first['task_name'] ?? first['taskName'])?.toString() ??
            taskNameController.text;
        taskNoteController.text =
            (first['task_note'])?.toString() ?? taskNoteController.text;

        // dueDate (accept String or DateTime)
        final dueDateRaw = first['due_date'];
        if (dueDateRaw != null) {
          if (dueDateRaw is String) {
            final parsed = DateTimeUtilsHelper.parseDate(dueDateRaw);
            if (parsed != null) _selectedDueDate = parsed;
          } else if (dueDateRaw is DateTime) {
            _selectedDueDate = dueDateRaw;
          }
        }

        // dueTime (accept String or DateTime)
        final dueTimeRaw = first['due_time'];
        if (dueTimeRaw != null) {
          if (dueTimeRaw is String) {
            final parsed = DateTimeUtilsHelper.parseTime(dueTimeRaw);
            if (parsed != null) _selectedDueTime = parsed;
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
        _selectedCategory = first['category']?.toString() ?? _selectedCategory;
        _selectedPriority = first['priority']?.toString() ?? _selectedPriority;
        _selectedRepeatType =
            first['repeat_type']?.toString() ?? _selectedRepeatType;

        // remainder amount & type
        final remAmount = first['reminder_amount'];
        if (remAmount != null) {
          reminderAmountController.text = remAmount.toString();
        }
        _selectedRemainderType =
            first['reminder_type']?.toString() ?? _selectedRemainderType;
        for (var subTask in first['subtasks']) {
          _addedSubtasks.add({
            "name": subTask['name'],
            "dueDate": DateTimeUtilsHelper.parseDate(subTask['due_date']),
            "dueTime": DateTimeUtilsHelper.parseTime(subTask['due_time']),
            "completed": false,
          });
        }
      }
    });
  }

  Future<void> _pickTime() async {
    // If no time selected yet, default to now
    final initialTime =
        _selectedDueTime != null
            ? TimeOfDay(
              hour: _selectedDueTime!.hour,
              minute: _selectedDueTime!.minute,
            )
            : TimeOfDay.now();
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
  }

  void _save() {
    final combined = DateTimeUtilsHelper.combineDateAndTime(
      _selectedDueDate,
      _selectedDueTime,
    );
    final utcTime = DateTimeUtilsHelper.toUtcUsingLocal(combined);

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
      'remainderAmount': int.tryParse(reminderAmountController.text) ?? 0,
      'remainderType': _selectedRemainderType,
      'subTasks': _addedSubtasks,
    };

    widget.onSave?.call(taskData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return makeDismissible(
      context: context,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder:
            (_, controller) => Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      children: [
                        // --- drag handle ---
                        Center(
                          child: Container(
                            height: 4,
                            width: 40,
                            decoration: BoxDecoration(
                              color: colors.trackOff,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- title ---
                        Text(
                          widget.buttonText == "Add Task"
                              ? 'Create New Task'
                              : 'Edit Task',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- task name + AI ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _LabeledField(
                                controller: taskNameController,
                                label: 'Task name or prompt text',
                                hint: 'What needs doing?',
                                autofocus: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            AiGenerationButton(
                              context: context,
                              goal: taskNameController,
                              timeframe: "tomorrow",
                              onResult: _applyAiResult,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- task note ---
                        _LabeledField(
                          controller: taskNoteController,
                          label: 'Task note',
                          hint: 'Add details (optional)',
                        ),
                        const SizedBox(height: 20),

                        _buildSubtasks(),
                        const SizedBox(height: 20),

                        _buildDueDate(),
                        const SizedBox(height: 20),

                        _buildOptionsCard(),
                        const SizedBox(height: 20),

                        _buildPriority(),
                        const SizedBox(height: 20),

                        _buildCategory(),
                      ],
                    ),
                  ),
                  // --- save button (pinned) ---
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.appColors.accent,
                          foregroundColor: context.appColors.onAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildSubtasks() {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Subtasks', count: _addedSubtasks.length),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _addedSubtasks.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _addedSubtasks.removeAt(oldIndex);
              _addedSubtasks.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final sub = _addedSubtasks[index];
            final bool done = sub['completed'] == true;
            return GestureDetector(
              key: ValueKey(sub['name'] + index.toString()), // for reorder
              onTap: () => _showEditSubTaskDialog(context, index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        size: 22,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CheckSquare(
                      checked: done,
                      onTap:
                          () => setState(
                            () => _addedSubtasks[index]['completed'] = !done,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub['name'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                              decoration:
                                  done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            "${DateTimeUtilsHelper.formatDate(sub['dueDate'] is String ? DateTime.tryParse(sub['dueDate']) : sub['dueDate'] as DateTime?)}  "
                            "${DateTimeUtilsHelper.formatTime(sub['dueTime'] is String ? DateTime.tryParse(sub['dueTime']) : sub['dueTime'] as DateTime?, format: 'hh:mm a')}",
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 22, color: colors.muted),
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          () => setState(() => _addedSubtasks.removeAt(index)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        InkWell(
          onTap: () => _showAddSubTaskDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20, color: context.appColors.accent),
                SizedBox(width: 6),
                Text(
                  'Add subtask',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDate() {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Due date'),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline),
          ),
          child: TableCalendar(
            startingDayOfWeek: DateTimeUtilsHelper.startingDayOfWeekFromSetting(
              widget.firstDayOfWeek,
            ),
            focusedDay: _selectedDueDate ?? DateTime.now(),
            firstDay: DateTime.utc(1969, 1, 1),
            lastDay: DateTime.utc(2100, 1, 1),
            rowHeight: 46,
            daysOfWeekHeight: 28,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDueDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() => _selectedDueDate = selectedDay);
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            calendarFormat: _calendarFormat,
            headerStyle: HeaderStyle(
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 18, color: cs.onSurface),
              headerPadding: const EdgeInsets.symmetric(vertical: 12),
              formatButtonPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              formatButtonTextStyle: TextStyle(
                fontSize: 12,
                color: colors.muted,
              ),
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: colors.muted),
                borderRadius: BorderRadius.circular(12),
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                size: 28,
                color: cs.onSurface,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                size: 28,
                color: cs.onSurface,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 12, color: colors.muted),
              weekendStyle: TextStyle(fontSize: 12, color: colors.muted),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(5),
              defaultTextStyle: TextStyle(fontSize: 15, color: cs.onSurface),
              weekendTextStyle: TextStyle(fontSize: 15, color: cs.onSurface),
              outsideTextStyle: TextStyle(
                fontSize: 15,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
              todayDecoration: BoxDecoration(
                color: cs.tertiary,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
              selectedDecoration: BoxDecoration(
                color: context.appColors.accent,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                fontSize: 15,
                color: context.appColors.onAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsCard() {
    final colors = context.appColors;
    final rows = <Widget>[
      OptionRow(
        icon: Icons.schedule,
        label: 'Set time',
        onTap: _pickTime,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedDueTime != null
                  ? DateTimeUtilsHelper.formatTime(
                    _selectedDueTime,
                    format: "hh:mm a",
                  ).toString()
                  : '',
              style: TextStyle(fontSize: 15, color: colors.muted),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: colors.muted),
          ],
        ),
      ),
      OptionRow(
        icon: Icons.star,
        label: 'Star this task',
        trailing: AppToggle(
          value: _isStarred,
          onChanged: (value) {
            setState(() => _isStarred = value);
          },
        ),
      ),
      OptionRow(
        icon: Icons.notifications,
        label: 'Remind before',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outline),
              ),
              child: TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: reminderAmountController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropChip(
              value: _selectedRemainderType,
              options: widget.remainderTypes,
              onChanged: (v) => setState(() => _selectedRemainderType = v),
            ),
          ],
        ),
      ),
      OptionRow(
        icon: Icons.repeat,
        label: 'Repeat',
        trailing: DropChip(
          value: _selectedRepeatType,
          options: widget.repeatTypes,
          onChanged: (v) => setState(() => _selectedRepeatType = v),
        ),
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 1, thickness: 1, color: colors.outline),
          ],
        ],
      ),
    );
  }

  Widget _buildPriority() {
    final colors = context.appColors;
    Color dot(String p) {
      switch (p) {
        case 'High':
          return colors.priorityHigh;
        case 'Medium':
          return colors.priorityMedium;
        default:
          return colors.priorityLow;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Priority'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < widget.priorityTypes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: SheetChip(
                  label: widget.priorityTypes[i],
                  selected: _selectedPriority == widget.priorityTypes[i],
                  dotColor: dot(widget.priorityTypes[i]),
                  center: true,
                  onTap:
                      () => setState(
                        () => _selectedPriority = widget.priorityTypes[i],
                      ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Category'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in widget.categoryTypes)
              SheetChip(
                label: option,
                selected: _selectedCategory == option,
                onTap: () => setState(() => _selectedCategory = option),
              ),
          ],
        ),
      ],
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

// ═════════════════════════════════════════════════════════════════════════
//  Small building blocks (mirror the Figma "Bottom sheets · Task" frames)
// ═════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  final int? count;
  const _SectionTitle(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 13, color: context.appColors.muted),
          ),
        ],
      ],
    );
  }
}

/// Outlined field with a small label above the value (Figma "Field").
class _LabeledField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  const _LabeledField({
    required this.controller,
    required this.label,
    required this.hint,
    this.autofocus = false,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final focused = _focus.hasFocus;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? context.appColors.accent : colors.outline,
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 16, color: colors.muted),
              contentPadding: const EdgeInsets.only(top: 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// 20 × 20 rounded checkbox: amber when checked, outlined when not.
class _CheckSquare extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const _CheckSquare({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checked ? context.appColors.accent : null,
          borderRadius: BorderRadius.circular(4),
          border:
              checked
                  ? null
                  : Border.all(color: context.appColors.muted, width: 2),
        ),
        child:
            checked
                ? Icon(Icons.check, size: 14, color: context.appColors.onAccent)
                : null,
      ),
    );
  }
}
