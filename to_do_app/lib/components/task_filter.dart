import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
//import 'package:to_do_app/pages/filtered_tasks_page.dart';
//import 'package:to_do_app/pages/saved_timetables_page.dart';

class TaskFilter extends StatefulWidget {
  final bool showCompleted;
  final bool showPending;
  final bool highPriorityOnly;
  final String? selectedFilter;
  final DateTime? selectedDueDate;
  final List<String> categoriesAndPriorities;
  final Function(Map<String, dynamic>)? onApply;

  const TaskFilter({
    super.key,
    this.onApply,
    required this.categoriesAndPriorities,
    required this.showCompleted,
    required this.showPending,
    required this.highPriorityOnly,
    required this.selectedFilter,
    required this.selectedDueDate,
  });

  @override
  State<TaskFilter> createState() => _TaskFilterState();
}

class _TaskFilterState extends State<TaskFilter> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  late bool showCompleted = widget.showCompleted;
  late bool showPending = widget.showPending;
  late bool highPriorityOnly = widget.highPriorityOnly;
  late String? selectedFilter = widget.selectedFilter;
  late DateTime? _selectedDueDate = widget.selectedDueDate;
  late List<String> categoriesAndPriorities = widget.categoriesAndPriorities;
  List<String> selectedCategories = [];
  Set<DateTime> selectedDates = {}; // For multiple date selection

  @override
  void initState() {
    super.initState();
    selectedFilter = "Selected_dates";
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.infinity,
        height: 900, // fixed height for dialog
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Filter Tasks",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Date:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    RadioListTile<String>(
                      title: const Text("Selected dates"),
                      value: "Selected_dates",
                      groupValue: selectedFilter,
                      onChanged: (value) {
                        setState(() => selectedFilter = value);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text("Before"),
                      value: "Before",
                      groupValue: selectedFilter,
                      onChanged: (value) {
                        setState(() => selectedFilter = value);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text("After"),
                      value: "After",
                      groupValue: selectedFilter,
                      onChanged: (value) {
                        setState(() => selectedFilter = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Select dates:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                      height: 400,
                      child: TableCalendar(
                        focusedDay: DateTime.now(),
                        firstDay: DateTime.utc(2000, 1, 1),
                        lastDay: DateTime.utc(2100, 1, 1),
                        selectedDayPredicate: (day) {
                          // check if the day is in the selectedDates set
                          return selectedDates.any((d) => isSameDay(d, day));
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            // toggle selection
                            if (selectedDates.any(
                              (d) => isSameDay(d, selectedDay),
                            )) {
                              selectedDates.removeWhere(
                                (d) => isSameDay(d, selectedDay),
                              );
                            } else {
                              selectedDates.add(selectedDay);
                            }
                          });
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
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Features:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children:
                          categoriesAndPriorities.where((e) => e != "None").map(
                            (category) {
                              return FilterChip(
                                label: Text(category),
                                selected: selectedCategories.contains(category),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedCategories.add(category);
                                    } else {
                                      selectedCategories.remove(category);
                                    }
                                  });
                                },
                              );
                            },
                          ).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Buttons pinned at bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onApply?.call({
                      'selectedFilterDates':
                          selectedDates.map((date) => date.toString()).toList(),
                      //'showPending': showPending,
                      //'highPriorityOnly': highPriorityOnly,
                      'selectedFilter': selectedFilter,
                      //'dueDate': _selectedDueDate,
                      'categories': selectedCategories,
                      'selectedDueDates': selectedDates,
                    });
                    Navigator.pop(context); //doesnt close backend of dialog
                  },
                  child: const Text("Apply"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
