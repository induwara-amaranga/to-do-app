import 'package:flutter/material.dart';
import 'package:to_do_app/components/bar_chart.dart';
import 'package:to_do_app/components/task_page_bottom_nav_bar.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/themes/app_colors.dart';
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

    // Parse the 7 week days once, not once per completed-task entry.
    final weekDays = {
      for (final d in selectedWeek)
        () {
          final day = DateTimeUtilsHelper.parseDateTime(d);
          return DateTime(day.year, day.month, day.day);
        }(),
    };
    for (var entry in groupedByCompletedDate.entries) {
      final DateTime completed = DateTimeUtilsHelper.parseDateTime(entry.key);
      if (weekDays.contains(
        DateTime(completed.year, completed.month, completed.day),
      )) {
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
    // One pass, deriving each task's due date once — this used to be four
    // separate filters over the whole list, each re-parsing every due date.
    missedTasks = [];
    pastTasks = [];
    pendingTasks = [];
    completedTasks = [];
    completedPastTasks = [];
    for (final task in toDoList) {
      if (task.completed) completedTasks.add(task);
      final DateTime? dueDateTimeUtc = _getUtcDateTime(task);
      if (dueDateTimeUtc == null) continue;
      if (dueDateTimeUtc.isBefore(today)) {
        pastTasks.add(task);
        (task.completed ? completedPastTasks : missedTasks).add(task);
      } else if (!task.completed) {
        pendingTasks.add(task);
      }
    }

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCircularProgressSection(),
            const SizedBox(height: 16),
            _buildPerformanceInsightCard(),
            const SizedBox(height: 16),
            _buildTaskSummaryCards(),
            const SizedBox(height: 16),
            _buildPriorityDistribution(),
            const SizedBox(height: 16),
            _buildWeeklyProgressChart(),
            const SizedBox(height: 16),
            _buildCategoryDistribution(),
          ],
        ),
      ),
      bottomNavigationBar: TaskBottomNavBar(current: 2),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Productivity',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: kAccent,
        ),
      ),
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  TextStyle get _heading => TextStyle(
    fontFamily: 'Manrope',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  TextStyle get _mutedText =>
      TextStyle(fontSize: 14, color: context.appColors.muted);

  /// One labelled horizontal bar: label, proportional track, count.
  Widget _barRow(String label, int count, int max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Container(height: 10, color: context.appColors.trackOff),
                  FractionallySizedBox(
                    widthFactor: max == 0 ? 0 : (count / max).clamp(0.0, 1.0),
                    child: Container(height: 10, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildCircularProgressSection() {
    final double rate =
        pastTasks.isNotEmpty ? completedPastTasks.length / pastTasks.length : 0;
    final String percentText =
        pastTasks.isNotEmpty ? '${(rate * 100).round()}%' : 'N/A';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: rate,
                        strokeWidth: 10,
                        backgroundColor: context.appColors.trackOff,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          kAccent,
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
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: context.appColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatChip(
                      '${completedPastTasks.length}',
                      'Completed In Past',
                    ),
                    const SizedBox(height: 12),
                    _buildStatChip('${missedTasks.length}', 'Missed In Past'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(_getMotivationText(), style: _mutedText),
        ],
      ),
    );
  }

  Widget _buildStatChip(String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.appColors.muted),
        ),
      ],
    );
  }

  Widget _buildPerformanceInsightCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: kAccent, size: 20),
              const SizedBox(width: 8),
              Text('Performance Insight', style: _heading),
            ],
          ),
          const SizedBox(height: 8),
          Text(_getBestDayInsight(), style: _mutedText),
        ],
      ),
    );
  }

  Widget _buildTaskSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Missed Tasks',
            count: missedTasks.length,
            dot: context.appColors.priorityHigh,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Pending Tasks',
            count: pendingTasks.length,
            dot: context.appColors.priorityMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required Color dot,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityDistribution() {
    final c = context.appColors;
    final rows = <(String, Color)>[
      ('High', c.priorityHigh),
      ('Medium', c.priorityMedium),
      ('Low', c.priorityLow),
    ];
    int countOf(String p) => groupedPendingTasksByPriority[p]?.length ?? 0;
    final int max = rows
        .map((r) => countOf(r.$1))
        .fold(0, (a, b) => a > b ? a : b);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending by Priority', style: _heading),
          for (final r in rows) _barRow(r.$1, countOf(r.$1), max, r.$2),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressChart() {
    final muted = context.appColors.muted;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Weekly Progress', style: _heading)),
              IconButton(
                onPressed: () {
                  setState(() {
                    groupedWeekByCompletedDate = {};
                    displayWeek++;
                    createWeekMap();
                  });
                },
                icon: Icon(Icons.chevron_left, color: muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${DateTimeUtilsHelper.displayDayMonth(firstDate, widget.db.settings)} – ${DateTimeUtilsHelper.displayDayMonth(lastDate, widget.db.settings)}',
                  style: TextStyle(fontSize: 12, color: muted),
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
                  color: displayWeek > 0 ? muted : muted.withValues(alpha: 0.3),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
    final entries =
        groupedPendingTasksByCategory.entries
            .where((e) => e.value.isNotEmpty)
            .toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final int max = entries.isEmpty ? 0 : entries.first.value.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending by Category', style: _heading),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No pending tasks', style: _mutedText)),
            )
          else
            for (final e in entries)
              _barRow(e.key, e.value.length, max, kAccent),
        ],
      ),
    );
  }
}
