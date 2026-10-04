import 'package:flutter/material.dart';
import 'package:to_do_app/components/task_tile.dart';
//import 'package:table_calendar/table_calendar.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/filter_tasks_service.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class Filteredtaskspage extends StatefulWidget {
  final Map<String, dynamic>? filterData;
  final List<Task> toDoList;
  final void Function(int, dynamic)? onTaskChanged;
  final Function(int, bool?)? onChanged;
  final Function(int)? deleteFunction;
  final List<String> categoryTypes;
  final AppSettings settings;

  const Filteredtaskspage({
    super.key,
    required this.categoryTypes,
    required this.deleteFunction,
    required this.onChanged,
    this.onTaskChanged,
    required this.filterData,
    required this.toDoList,
    this.settings = const AppSettings(),
  });

  @override
  State<Filteredtaskspage> createState() => _FilteredtaskspageState();
}

class _FilteredtaskspageState extends State<Filteredtaskspage> {
  List<String> repeatTypes = ["daily", "weekly", "monthly", "yearly"];
  List<String> priorityTypes = ["Low", "Medium", "High"];
  List<String> remainderTypes = ["minutes", "hours", "days"];
  List<Task> filteredTasks = [];

  @override
  void initState() {
    super.initState();
    filteredTasks = FilterTasksService.filterTasksByCategory(
      widget.toDoList,
      widget.filterData,
    );
  }

  List<Widget> _buildFilterChips(ColorScheme colorScheme) {
    final chips = <Widget>[];
    final filterData = widget.filterData;
    if (filterData == null) return chips;

    final categories = (filterData['categories'] as List<dynamic>? ?? []);
    for (final cat in categories) {
      chips.add(
        Chip(
          label: Text(
            cat.toString(),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: colorScheme.secondary,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final selectedDates =
        filterData['selectedDueDates'] as Set<DateTime>? ?? {};
    final selectedFilter = filterData['selectedFilter'] as String?;

    if (selectedDates.isNotEmpty) {
      if (selectedFilter == 'Before' || selectedFilter == 'After') {
        final date = selectedDates.first;
        chips.add(
          Chip(
            avatar: Icon(
              selectedFilter == 'Before'
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              size: 14,
              color: colorScheme.onPrimary,
            ),
            label: Text(
              '${selectedFilter == 'Before' ? 'Before' : 'After'} ${DateTimeUtilsHelper.displayDayMonth(date, widget.settings)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: colorScheme.primary,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            visualDensity: VisualDensity.compact,
          ),
        );
      } else {
        for (final date in selectedDates) {
          chips.add(
            Chip(
              avatar: Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: colorScheme.onPrimary,
              ),
              label: Text(
                DateTimeUtilsHelper.displayDayMonth(date, widget.settings),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: colorScheme.primary,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              visualDensity: VisualDensity.compact,
            ),
          );
        }
      }
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filterChips = _buildFilterChips(colorScheme);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(
          '    Filtered Tasks',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        //backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: colorScheme.onPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filterChips.isEmpty)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Chip(
                avatar: Icon(
                  Icons.filter_list_rounded,
                  size: 13,
                  color: colorScheme.onPrimary,
                ),
                label: Text(
                  'No filters applied',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: colorScheme.primary,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              ),
            ),

          if (filterChips.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(spacing: 8, children: filterChips),
            ),
          filteredTasks.isEmpty
              ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_off_rounded,
                        size: 72,
                        color: colorScheme.inversePrimary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "No tasks found",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Try adjusting your filters",
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        "${filteredTasks.length} task${filteredTasks.length == 1 ? '' : 's'}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Expanded(
                      // A plain lazily-built list: the old SingleChildScrollView
                      // + shrinkWrap combination laid out every result at once.
                      child: ReorderableListView.builder(
                        itemCount: filteredTasks.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = filteredTasks.removeAt(oldIndex);
                            filteredTasks.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];

                          return Container(
                            key: ObjectKey(task),
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 12,
                            ),
                            child: TaskTile(
                              source: task.source,
                              disableCompleted: () {},
                              initialSubtasks:
                                  task.subtasks.map((s) => s.toMap()).toList(),
                              index: widget.toDoList.indexOf(task),
                              isStarred: task.isStarred,
                              taskName: task.name,
                              taskCompleted: task.completed,
                              taskNote: task.note ?? '',
                              dueDate: DateTimeUtilsHelper.parseDate(
                                task.dueDate,
                              ),
                              dueTime:
                                  task.dueTime != "00:00"
                                      ? DateTimeUtilsHelper.parseTime(
                                        task.dueTime!,
                                      )
                                      : null,
                              taskCategory: task.category,
                              taskPriority: task.priority,
                              repeatType: task.repeatType!,
                              remainderAmount: task.reminderAmount,
                              remainderType: task.reminderType!,
                              onChanged: (index, value) {
                                setState(() {
                                  widget.onChanged?.call(index, value);
                                });
                              },
                              deleteFunction: (index) {
                                setState(() {
                                  widget.deleteFunction?.call(index);
                                });
                              },
                              onEdit: (index, taskDetails) {
                                setState(() {
                                  widget.onTaskChanged?.call(
                                    index,
                                    taskDetails,
                                  );
                                });
                              },
                              repeatTypes: repeatTypes,
                              priorityTypes: priorityTypes,
                              remainderTypes: remainderTypes,
                              categoryTypes: widget.categoryTypes,
                              playCompletionTone:
                                  widget.settings.completionTone,
                              playCompletionAnimation:
                                  widget.settings.completionAnimation,
                              settings: widget.settings,
                            ),
                          );
                        },
                      ),
                    ),
                    //SizedBox(height: 20),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
