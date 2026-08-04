import 'package:flutter/material.dart';
import 'package:to_do_app/components/bar_chart.dart';
import 'package:to_do_app/components/pie_chart.dart';
import 'package:to_do_app/components/task_page_bottom_nav_bar.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

class StatisticsPage extends StatefulWidget {
  final ToDoDataBase db;
  const StatisticsPage({super.key, required this.db});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime today = DateTime.now().toUtc();
  late DateTime firstDate;
  late DateTime lastDate;
  int displayWeek = 0;

  late List<Task> toDoList;
  late List<Task> missedTasks;
  late List<Task> pendingTasks;
  late List<Task> completedTasks;
  late List<Task> completedPastTasks;
  late List<Task> pastTasks;
  Map<String, List<Task>> groupedByCompletedDate = {};
  Map<int, List<Task>> groupedWeekByCompletedDate = {};
  List<String> selectedWeek = [];

  Map<String, List<Task>> groupedMissedTasksByPriority = {
    'Low': [],
    'Medium': [],
    'High': [],
  };
  Map<String, List<Task>> groupedPendingTasksByPriority = {
    'Low': [],
    'Medium': [],
    'High': [],
  };
  Map<String, List<Task>> groupedPendingTasksByCategory = {};

  DateTime? _getUtcDateTime(Task task) {
    if (task.dueDate == null || task.dueDate == "0000-00-00") return null;
    final combined = DateTimeUtilsHelper.combineDateAndTimeFromStrings(
      task.dueDate!,
      task.dueTime!,
    );
    return DateTime.utc(
      combined.year,
      combined.month,
      combined.day,
      combined.hour,
      combined.minute,
    );
  }

  List<DateTime> _getWeekDates({
    int weeksAgo = 0,
    bool startFromMonday = true,
  }) {
    final now = DateTime.now().toUtc();
    int currentWeekday = now.weekday;
    int diff = startFromMonday ? currentWeekday - 1 : currentWeekday % 7;
    DateTime startOfCurrentWeek = now.subtract(Duration(days: diff));
    DateTime startOfTargetWeek = startOfCurrentWeek.subtract(
      Duration(days: 7 * weeksAgo),
    );
    return List.generate(
      7,
      (index) => startOfTargetWeek.add(Duration(days: index)),
    );
  }

  void createWeekMap() {
    selectedWeek =
        _getWeekDates(
          startFromMonday: false,
          weeksAgo: displayWeek,
        ).map((e) => e.toString()).toList();

    groupedWeekByCompletedDate = {};
    for (var day in _getWeekDates(
      startFromMonday: false,
      weeksAgo: displayWeek,
    )) {
      groupedWeekByCompletedDate[day.weekday] = [];
    }

    for (var entry in groupedByCompletedDate.entries) {
      final DateTime completed = DateTimeUtilsHelper.parseDateTime(entry.key);
      if (selectedWeek.any((d) {
        final DateTime day = DateTimeUtilsHelper.parseDateTime(d);
        return day.year == completed.year &&
            day.month == completed.month &&
            day.day == completed.day;
      })) {
        if (groupedWeekByCompletedDate.containsKey(completed.weekday)) {
          groupedWeekByCompletedDate[completed.weekday]!.addAll(entry.value);
        } else {
          groupedWeekByCompletedDate[completed.weekday] = List.from(
            entry.value,
          );
        }
      }
    }
    firstDate = DateTimeUtilsHelper.parseDateTime(selectedWeek[0]);
    lastDate = DateTimeUtilsHelper.parseDateTime(selectedWeek.last);
    firstDate = DateTimeUtilsHelper.toLocalUsingTz(firstDate);
    lastDate = DateTimeUtilsHelper.toLocalUsingTz(lastDate);
  }

  String _getBestDayInsight() {
    Map<int, int> weekdayCounts = {};
    for (var entry in groupedByCompletedDate.entries) {
      final dt = DateTimeUtilsHelper.parseDateTime(entry.key);
      weekdayCounts[dt.weekday] =
          (weekdayCounts[dt.weekday] ?? 0) + entry.value.length;
    }
    if (weekdayCounts.isEmpty) {
      return 'Keep adding and completing tasks to see your productivity insights.';
    }
    final best = weekdayCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = days[best.key - 1];
    final count = best.value;
    return '$dayName is your most productive day with $count task${count == 1 ? '' : 's'} completed. Schedule your high-priority tasks then for best results.';
  }

  String _getMotivationText() {
    if (pastTasks.isEmpty) return 'Start adding tasks to track your progress!';
    final rate = completedPastTasks.length / pastTasks.length;
    if (rate >= 0.8) return 'Outstanding! You are on fire. Keep it up!';
    if (rate >= 0.6) return 'You are doing great! Keep up the good work.';
    if (rate >= 0.4)
      return 'Good progress! Push a little harder to hit your goals.';
    return 'Stay focused! Tackle your high-priority tasks first.';
  }

  @override
  void initState() {
    super.initState();
    groupedPendingTasksByCategory = {
      for (var e in widget.db.categories) e: <Task>[],
    };

    toDoList = widget.db.toDoList;
    missedTasks =
        toDoList.where((task) {
          DateTime? dueDateTimeUtc = _getUtcDateTime(task);
          if (dueDateTimeUtc == null) return false;
          return dueDateTimeUtc.isBefore(today) && task.completed == false;
        }).toList();
    pastTasks =
        toDoList.where((task) {
          DateTime? dueDateTimeUtc = _getUtcDateTime(task);
          if (dueDateTimeUtc == null) return false;
          return dueDateTimeUtc.isBefore(today);
        }).toList();
    pendingTasks =
        toDoList.where((task) {
          final dueDateTimeUtc = _getUtcDateTime(task);
          if (dueDateTimeUtc == null) return false;
          return !dueDateTimeUtc.isBefore(today) && task.completed == false;
        }).toList();
    completedTasks = toDoList.where((task) => task.completed == true).toList();
    completedPastTasks =
        completedTasks.where((task) {
          final dueDateTimeUtc = _getUtcDateTime(task);
          if (dueDateTimeUtc == null) return false;
          return dueDateTimeUtc.isBefore(today) && task.completed == true;
        }).toList();

    for (var task in pendingTasks) {
      String priority = task.priority;
      if (groupedPendingTasksByPriority.containsKey(priority)) {
        groupedPendingTasksByPriority[priority]!.add(task);
      } else {
        groupedPendingTasksByPriority[priority] = [task];
      }
    }
    for (var task in missedTasks) {
      String priority = task.priority;
      if (groupedMissedTasksByPriority.containsKey(priority)) {
        groupedMissedTasksByPriority[priority]!.add(task);
      } else {
        groupedMissedTasksByPriority[priority] = [task];
      }
    }
    for (var task in pendingTasks) {
      String category = task.category;
      if (groupedPendingTasksByCategory.containsKey(category)) {
        groupedPendingTasksByCategory[category]!.add(task);
      } else {
        groupedPendingTasksByCategory[category] = [task];
      }
    }
    for (var task in completedTasks) {
      DateTime completedDate = DateTimeUtilsHelper.parseDateTime(
        task.completedAt!,
      );
      String key = completedDate.toString();
      if (groupedByCompletedDate.containsKey(key)) {
        groupedByCompletedDate[key]!.add(task);
      } else {
        groupedByCompletedDate[key] = [task];
      }
    }
    createWeekMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: 24,
          left: 16,
          right: 16,
          bottom: 96,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCircularProgressSection(),
            const SizedBox(height: 24),
            _buildTaskSummaryCards(),
            const SizedBox(height: 24),
            _buildWeeklyProgressChart(),
            const SizedBox(height: 24),
            _buildCategoryDistribution(),
            const SizedBox(height: 24),
            _buildPerformanceInsightCard(),
          ],
        ),
      ),
      bottomNavigationBar: TaskBottomNavBar(current: 2),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              Icons.bolt,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Productivity',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.4,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgressSection() {
    final double rate =
        pastTasks.isNotEmpty ? completedPastTasks.length / pastTasks.length : 0;
    final String percentText =
        pastTasks.isNotEmpty ? '${(rate * 100).round()}%' : 'N/A';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 192,
                height: 192,
                child: CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 12,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    percentText,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  const Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      letterSpacing: 1.6,
                      color: Color(0xFF584237),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getMotivationText(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(
                '${completedPastTasks.length}',
                'Completed In Past',
              ),
              const SizedBox(width: 24),
              _buildStatChip('${missedTasks.length}', 'Missed In Past'),
              //const SizedBox(width: 24),
              //_buildStatChip('${pendingTasks.length}', 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B1C30),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            color: Color(0xFF584237),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildTaskCard(
            title: 'Missed Tasks',
            count: missedTasks.length.toString(),
            countColor: const Color(0xFFBA1A1A),
            priorityMap: groupedMissedTasksByPriority,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTaskCard(
            title: 'Pending Tasks',
            count: pendingTasks.length.toString(),
            countColor: Theme.of(context).colorScheme.primary,
            priorityMap: groupedPendingTasksByPriority,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String count,
    required Color countColor,
    required Map<String, List<Task>> priorityMap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: Color(0xFF584237),
                  ),
                ),
              ),
              Text(
                count,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.32,
                  color: countColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPriorityItem(
            'High',
            priorityMap['High']?.length ?? 0,
            const Color(0xFFFEE2E2),
            const Color(0xFFBA1A1A),
          ),
          const SizedBox(height: 6),
          _buildPriorityItem(
            'Medium',
            priorityMap['Medium']?.length ?? 0,
            const Color(0xFFFEF9C3),
            const Color(0xFFA16207),
          ),
          const SizedBox(height: 6),
          _buildPriorityItem(
            'Low',
            priorityMap['Low']?.length ?? 0,
            const Color(0xFFDCFCE7),
            const Color(0xFF166534),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityItem(
    String label,
    int count,
    Color badgeBg,
    Color badgeTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: Color(0xFF0B1C30),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                'Weekly Progress',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  color: Color(0xFF0B1C30),
                  fontWeight: FontWeight.bold,
                ),
              ),

              //Spacer(),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        groupedWeekByCompletedDate = {};
                        displayWeek++;
                        createWeekMap();
                      });
                    },
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF584237),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      '${DateTimeUtilsHelper.displayDayMonth(firstDate, widget.db.settings)}-${DateTimeUtilsHelper.displayDayMonth(lastDate, widget.db.settings)}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: Color(0xFF584237),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        displayWeek > 0
                            ? () {
                              setState(() {
                                groupedWeekByCompletedDate = {};
                                displayWeek--;
                                createWeekMap();
                              });
                            }
                            : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color:
                          displayWeek > 0
                              ? const Color(0xFF584237)
                              : Colors.grey.shade300,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: MyBarChart(
              mappedWeek: groupedWeekByCompletedDate,
              isFromMonday: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending by Category',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              color: Color(0xFF0B1C30),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          pendingTasks.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No pending tasks',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: Color(0xFF584237),
                    ),
                  ),
                ),
              )
              : SizedBox(
                height: 200,
                child: MyPieChart(
                  color: Theme.of(context).colorScheme.primary,
                  mappedPending: groupedPendingTasksByCategory,
                  total: pendingTasks.length,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1C30),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 25,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insights,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Insight',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getBestDayInsight(),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: Color(0xFFCBD5E1),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInsightStat('${toDoList.length}', 'Total'),
                _buildInsightStat('${completedTasks.length}', 'Done'),
                _buildInsightStat('${missedTasks.length}', 'Missed'),
                _buildInsightStat('${pendingTasks.length}', 'Pending'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightStat(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
