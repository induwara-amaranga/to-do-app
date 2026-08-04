import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/components/sync_tile.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/sub_task.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/types.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/components/create_task_sheet.dart';
import 'package:to_do_app/components/drawer.dart';
import 'package:to_do_app/components/task_page_appbar.dart';
import 'package:to_do_app/components/task_page_bottom_nav_bar.dart';
import 'package:to_do_app/components/task_tile.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'package:to_do_app/services/cordinate_calendars.dart';
import 'package:to_do_app/services/google_calendar_service.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/local_calendar_service.dart';
import 'package:to_do_app/services/group_tasks_service.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/services/outlook_calendar_service.dart';
import 'package:to_do_app/services/outlook_sign.dart';
import 'package:to_do_app/services/repeat_task.dart';
import 'package:to_do_app/services/search_tasks.dart';
import 'package:to_do_app/services/sort_tasks_service.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:uuid/uuid.dart';

class TaskPage extends StatefulWidget {
  final ToDoDataBase db;
  final bool updateMissedTasks;
  final String? filePath;
  const TaskPage({
    super.key,
    required this.filePath,
    required this.updateMissedTasks,
    required this.db,
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with TickerProviderStateMixin {
  List<Task> toDoList = [];
  late Map<String, List<Task>> hotTasks;

  // null = no warning; non-null = warning color to display
  Color? warningColor;

  final uuid = Uuid();
  late TabController _tabController;
  bool isDuringAnimation = false;

  bool _isStarred = false;
  String _selectedCategory = "None";
  List<String> _hidingCategories = []; // kept in sync with db.hidingCategories

  final _taskNameController = TextEditingController();
  final _taskNoteController = TextEditingController();
  final _remainderAmountController = TextEditingController();

  late ToDoDataBase db;

  // ── Tabs ──────────────────────────────────────────────────────────────────

  List<Tab> _taskCategoryTabs() {
    int pendingCount(String tabName) {
      final List<Task> tasks;
      if (tabName == 'All') {
        tasks = db.toDoList;
      } else if (db.categories.contains(tabName)) {
        tasks = db.toDoList.where((t) => t.category == tabName).toList();
      } else {
        tasks = db.toDoList.where((t) => t.priority == tabName).toList();
      }
      return tasks.where((t) => !t.completed).length;
    }

    String label(String name) {
      final n = pendingCount(name);
      return n > 0 ? '$name  $n' : name;
    }

    return [
      Tab(text: label('All')),
      ...db.categories
          .where((c) => c != 'None' && !_hidingCategories.contains(c))
          .map((d) => Tab(text: label(d))),
      Tab(text: label('High')),
      Tab(text: label('Medium')),
      Tab(text: label('Low')),
    ];
  }

  // ── Category management ───────────────────────────────────────────────────

  void changeCategories(
    List<String> newCategories,
    List<String> hidingCategories,
    Map<String, String> edittingCategories,
  ) {
    db.categories = newCategories;
    _hidingCategories = hidingCategories;
    db.hidingCategories = hidingCategories;
    db.saveHidingCategories();
    _tabController.dispose();
    _tabController = TabController(
      length: _taskCategoryTabs().length,
      vsync: this,
    );
    setState(() {
      for (int i = 0; i < db.toDoList.length; i++) {
        final task = db.toDoList[i];
        String currentCategory = task.category;
        if (edittingCategories.containsKey(currentCategory)) {
          db.toDoList[i].category = edittingCategories[currentCategory]!;
          currentCategory = db.toDoList[i].category;
        }
      }
      if (hidingCategories.contains(_selectedCategory)) {
        _selectedCategory = "None";
      } else if (edittingCategories.containsKey(_selectedCategory)) {
        _selectedCategory = edittingCategories[_selectedCategory]!;
      }
    });
    // Only tasks + category metadata changed — leave the calendar boxes alone.
    db.saveTasksAndCategories();
  }

  // ── Task CRUD ─────────────────────────────────────────────────────────────

  void checkBoxChanged(bool? value, int index) async {
    if (value != null) {
      db.toDoList[index].completedAt =
          value ? DateTime.now().toUtc().toString() : "none";
    }
    final bool spawnsRepeat =
        value == true && db.toDoList[index].repeatType != "none";
    setState(() {
      db.toDoList[index].completed = !db.toDoList[index].completed;
      toDoList = db.toDoList;
      hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
    });

    // A toggle touches exactly one record — write only that one. Done before
    // the repeat handling below because that has several early-return paths
    // that never reach a save of their own.
    await db.saveTaskAt(index);

    if (spawnsRepeat && mounted) {
      // Appends the next occurrence and persists the list when it does.
      await RepeatTask.createNextRepeatTask(context, index, db);
      if (!mounted) return;
      setState(() {
        toDoList = db.toDoList;
        hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
      });
    }
  }

  void saveNewTask(Map<String, dynamic> taskDetails) async {
    final selectedRepeatType = taskDetails['repeatType'];
    final selectedRemainderAmount = taskDetails['remainderAmount'];
    final String id = uuid.v4();
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
      isStarred:
          taskDetails['isStarred'] == "true" ||
          taskDetails['isStarred'] == true,
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
    // Appends one record to the box instead of rewriting it.
    await db.appendTask(task);
    if (mounted) setState(() {});
    if (selectedRemainderAmount >= 0 &&
        selectedRepeatType != "none" &&
        mounted) {
      await NotificationService.scheduleInitialRemainderForTask(
        id,
        context,
        taskDetails,
        db,
        db.toDoList.length - 1,
      );
    }
    toDoList = db.toDoList;
    await CordinateCalendars.addUpdateTaskToCalendars(db, task);
    hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
    // Re-save the one record: the calendar fan-out fills in remoteEventIds.
    await db.saveTaskAt(db.toDoList.indexOf(task));
    _taskNameController.clear();
    _taskNoteController.clear();
    _remainderAmountController.clear();
  }

  void deleteTask(int index) async {
    final deletedTask = db.toDoList[index];

    for (int id in db.toDoList[index].notificationIds) {
      await NotificationService.cancelNotification(id);
    }
    await CordinateCalendars.deleteTaskFromCalendars(db, db.toDoList[index]);
    // Deletes one record from the box rather than rewriting all of them.
    await db.removeTaskAt(index);
    if (!mounted) return;
    setState(() {
      toDoList = db.toDoList;
      hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Task deleted"),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: "Undo",
          onPressed: () {
            setState(() {
              db.toDoList.insert(index, deletedTask);
            });
            // Mid-list insert shifts every later key — Hive has no insert-at,
            // so this one genuinely needs the full task-box rewrite.
            db.saveToDoList();
          },
        ),
      ),
    );
  }

  void editTask(int index, Map<String, dynamic> taskDetails) async {
    final String id = uuid.v4();
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
      await NotificationService.cancelNotification(id);
    }
    if (taskDetails['remainderAmount'] >= 0 &&
        taskDetails['remainderType'] != "none") {
      await NotificationService.scheduleInitialRemainderForTask(
        id,
        context,
        taskDetails,
        db,
        index,
      );
    }
    toDoList = db.toDoList;
    hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
    await CordinateCalendars.addUpdateTaskToCalendars(db, db.toDoList[index]);
    // An edit rewrites one record in place.
    await db.saveTaskAt(index);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    print("task page zone: ${tz.local.name}");
    db = widget.db;
    _hidingCategories = List<String>.from(db.hidingCategories);

    _remainderAmountController.text = "0";
    _tabController = TabController(
      length: _taskCategoryTabs().length,
      vsync: this,
    );

    grouping = context.read<GroupingProvider>().mode;
    sortingProvider = context.read<SortingProvider>();
    sorting = sortingProvider.mode;
    query = context.read<SearchingProvider>().query;

    toDoList = db.toDoList;
    hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Safe to use context and show dialogs here
      if (widget.updateMissedTasks) {
        RepeatTask.createPendingRepeatTasks(db, context);
      }

      if (db.syncToCalendars["google"] != "none") {
        try {
          await GoogleAuthService.ensureApisReady();
        } catch (d) {
          print("Failed to restore Google APIs: $d");
        }
      }
      if (db.syncToCalendars["outlook"] != "none") {
        try {
          await OutlookAuthService.acquireTokenSilently();
        } catch (d) {
          print("Failed to restore Outlook session: $d");
        }
      }
      await importViewOnly();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    _taskNameController.dispose();
    _taskNoteController.dispose();
    _remainderAmountController.dispose();
    super.dispose();
  }

  late SortingProvider sortingProvider;
  late GroupingMode grouping;
  late SortingMode sorting;
  late String query;

  bool showCompletedTasks = false;

  final ScrollController _scrollController = ScrollController();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    grouping = context.watch<GroupingProvider>().mode;
    sortingProvider = context.watch<SortingProvider>();
    sorting = sortingProvider.mode;
    // Deliberately NOT watching CalendarSyncProvider here: its progress ticks
    // fire several times per sync and would rebuild the whole page (and every
    // tab's sort → filter → group pipeline) for a number that only the sync
    // bar displays. The Consumer around _buildSyncBar scopes it to that bar.
    query = context.watch<SearchingProvider>().query;

    return Scaffold(
      drawer: MyDrawer(
        db: db,
        filePath: widget.filePath,
        onImported: () {
          db.loadData();
          _tabController.dispose();
          _tabController = TabController(
            length: _taskCategoryTabs().length,
            vsync: this,
          );
          toDoList = db.toDoList;
          hotTasks = getUpcomingTasksWithinHotPeriod(toDoList);
          setState(() {});
        },
      ),
      key: _scaffoldKey,
      bottomNavigationBar: const TaskBottomNavBar(current: 1),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            TaskPageAppBar(
              db: db,
              hidingCategories: _hidingCategories,
              onCategoryChanged:
                  (newC, hidden, editting) =>
                      changeCategories(newC, hidden, editting),
              categoryTypes: db.categories,
              onChanged: (index, value) => checkBoxChanged(value, index),
              deleteFunction: (index) => deleteTask(index),
              onTaskChnaged: (index, taskDetails) {
                setState(() {
                  editTask(index, taskDetails);
                });
              },
              pageContext: context,
              categoriesAndPriorities:
                  db.categories +
                  ["High", "Medium", "Low"] +
                  ["Completed", "Pending", "Missed"],
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              taskCategoryTabs: _taskCategoryTabs,
              tabController: _tabController,
            ),
          ];
        },
        // Body uses a Column so the warning banner and sync bar
        // don't overlap the tab content
        body: Column(
          children: [
            // Warning banner — replaces the overlapping warning FAB
            if (warningColor != null) _buildWarningBanner(),
            // Sync progress bar — full-width, theme-aware
            Consumer<CalendarSyncProvider>(
              builder: (_, sync, __) {
                if (!sync.isSyncing) return const SizedBox.shrink();
                return _buildSyncBar(sync);
              },
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                // Each tab is wrapped in a Builder so its sort → filter →
                // search → group pipeline runs when TabBarView actually builds
                // that page, not eagerly for all ~8 tabs on every rebuild.
                children:
                    _taskCategoryTabs().map((tab) {
                      return Builder(
                        builder:
                            (_) => _buildTasksForTab(
                              tab.text,
                              grouping,
                              sorting,
                              query,
                            ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "Add_Task",
            tooltip: 'Add task',
            onPressed:
                () => showModalBottomSheet(
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
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
                        onSave: (taskDetails) => saveNewTask(taskDetails),
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
                        initialRemainderType:
                            db.settings.reminderTypeNormalized,
                        firstDayOfWeek: db.settings.firstDayOfWeek,
                      ),
                ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.add_rounded),
          ),
          const SizedBox(height: 10),
          // AnimatedSwitcher hides the FAB cleanly during completion animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                isDuringAnimation
                    ? const SizedBox(
                      key: ValueKey('hidden'),
                      height: 56,
                      width: 56,
                    )
                    : FloatingActionButton(
                      key: const ValueKey('visible'),
                      heroTag: "Completed_Tasks",
                      tooltip:
                          showCompletedTasks
                              ? 'Hide completed'
                              : 'Show completed',
                      onPressed:
                          () => setState(
                            () => showCompletedTasks = !showCompletedTasks,
                          ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        showCompletedTasks
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _buildWarningBanner() {
    return GestureDetector(
      onTap: () => showPendingPriorityTasksDialog(context),
      child: Container(
        width: double.infinity,
        color: warningColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Urgent tasks need attention — tap to review',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBar(CalendarSyncProvider sync) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            'Syncing ${(sync.progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: sync.progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // Formats stored group keys into human-readable labels
  String _formatGroupKey(String key) {
    if (key.toLowerCase() == 'today') return 'Today';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
      final dt = DateTime.tryParse(key);
      if (dt != null) {
        return DateTimeUtilsHelper.displayDateFriendly(dt, db.settings);
      }
    }
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(key)) {
      final dt = DateTime.tryParse('$key-01');
      if (dt != null)
        return DateTimeUtilsHelper.displayMonthYear(dt, db.settings);
    }
    if (RegExp(r'^\d{4}$').hasMatch(key)) return key;
    return key.toUpperCase();
  }

  String _formatDueDate(String? date, String? time) {
    if (date == null || date.isEmpty) return 'No date';
    final dt = DateTime.tryParse('$date ${time ?? ""}');
    if (dt == null) return date;
    return '${DateTimeUtilsHelper.displayDateFriendly(dt, db.settings)} '
        '${DateTimeUtilsHelper.displayTime(dt, db.settings)}';
  }

  // ── Tab content builder ───────────────────────────────────────────────────

  Widget _buildTasksForTab(
    String? tabName,
    GroupingMode grouping,
    SortingMode sorting,
    String query,
  ) {
    // Strip count badge suffix added by _taskCategoryTabs()
    // e.g., "All  10" → "All", "High  3" → "High", "Work  2" → "Work"
    final String name =
        (tabName ?? '').replaceAll(RegExp(r'\s+\d+$'), '').trim();

    List<Task> tasksOfThisTab;

    if (name == "All") {
      tasksOfThisTab = SortTasksService.sortTasksByMode(db.toDoList, sorting);
    } else if (db.categories.contains(name)) {
      tasksOfThisTab = db.toDoList.where((t) => t.category == name).toList();
    } else if (["High", "Medium", "Low"].contains(name)) {
      tasksOfThisTab = db.toDoList.where((t) => t.priority == name).toList();
    } else {
      tasksOfThisTab = [];
    }

    if (showCompletedTasks) {
      tasksOfThisTab = tasksOfThisTab.where((t) => t.completed).toList();
    } else {
      tasksOfThisTab = tasksOfThisTab.where((t) => !t.completed).toList();
    }

    tasksOfThisTab = SearchTasks.searchByQuery(query, tasksOfThisTab);
    tasksOfThisTab = SortTasksService.sortTasksByMode(tasksOfThisTab, sorting);

    final Map<String, List<Task>> grouped = GroupTasksService.groupTasksByMode(
      tasksOfThisTab,
      grouping,
      showCompletedTasks,
    );

    // Empty state
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showCompletedTasks ? Icons.task_alt : Icons.checklist_rtl,
              size: 72,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              showCompletedTasks ? 'No completed tasks' : 'No tasks here',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            if (!showCompletedTasks) ...[
              const SizedBox(height: 6),
              Text(
                'Tap + to add one',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final Map<String, bool> expandedGroups = {
      "today": true,
      DateTime.now().toString().substring(0, 7): true,
      DateTime.now().toString().substring(0, 4): true,
      DateTime.now().toString().substring(0, 10): true,
      DateTime.now().year.toString(): true,
    };

    final groupEntries = grouped.entries.toList();

    return RefreshIndicator(
      onRefresh: importViewOnly,
      // .builder, not ListView(children:), so a long "by month"/"by year"
      // history doesn't construct every group's Card + ExpansionTile up front.
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: groupEntries.length,
        itemBuilder: (context, groupIndex) {
          final entry = groupEntries[groupIndex];
          final groupKey = entry.key;
          final groupTasks = entry.value;

          return StatefulBuilder(
            builder: (context, setInnerState) {
              final isExpanded = expandedGroups[groupKey] ?? false;

              // Collect today's calendar events once for this group
              final todayCalEvents =
                  groupKey == 'today' && !showCompletedTasks
                      ? [
                        ...db.localCalTasks.where(_isCalEventForToday),
                        ...db.googleCalTasks.where(_isCalEventForToday),
                        ...db.outlookCalTasks.where(_isCalEventForToday),
                      ]
                      : <CalendarEvent>[];

              return Card(
                // Fix: use theme surface color instead of hardcoded white
                color: Theme.of(context).colorScheme.surface,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    initiallyExpanded: isExpanded,
                    // Fix: display human-readable date labels
                    title: Text(
                      _formatGroupKey(groupKey),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onExpansionChanged:
                        (val) =>
                            setInnerState(() => expandedGroups[groupKey] = val),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tasks',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),

                          if (groupTasks.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "No tasks",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: groupTasks.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final movingTaskId = groupTasks[oldIndex].id;
                                final destinationTaskID =
                                    groupTasks[newIndex].id;
                                final int from = db.toDoList.indexWhere(
                                  (task) => task.id == movingTaskId,
                                );
                                final int to = db.toDoList.indexWhere(
                                  (task) => task.id == destinationTaskID,
                                );
                                final task = db.toDoList.removeAt(from);
                                db.toDoList.insert(to, task);
                                // Reorder changes every key from `to`
                                // onward — full task-box rewrite required.
                                db.saveToDoList();
                                sortingProvider.setMode(SortingMode.manual);
                                setState(() {});
                              },
                              itemBuilder: (context, index) {
                                final task = groupTasks[index];
                                return Padding(
                                  key: ValueKey(
                                    '${task.name}_${task.id}_${task.toString()}',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: TaskTile(
                                    source: task.source,
                                    disableCompleted: () {
                                      setState(() {
                                        isDuringAnimation = !isDuringAnimation;
                                      });
                                    },
                                    initialSubtasks:
                                        task.subtasks
                                            .map((s) => s.toMap())
                                            .toList(),
                                    index: db.toDoList.indexOf(task),
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
                                    onChanged:
                                        (index, value) =>
                                            checkBoxChanged(value, index),
                                    deleteFunction:
                                        (context) => deleteTask(
                                          db.toDoList.indexOf(task),
                                        ),
                                    onEdit:
                                        (index, taskDetails) =>
                                            editTask(index, taskDetails),
                                    repeatTypes: repeatTypes,
                                    priorityTypes: priorityTypes,
                                    remainderTypes: remainderTypes,
                                    categoryTypes: db.categories,
                                    playCompletionTone:
                                        db.settings.completionTone,
                                    playCompletionAnimation:
                                        db.settings.completionAnimation,
                                    settings: db.settings,
                                  ),
                                );
                              },
                            ),

                          // Calendar events section — only for "today" group,
                          // header guarded so it only shows when events exist
                          if (todayCalEvents.isNotEmpty &&
                              !showCompletedTasks) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Calendar Events',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...todayCalEvents.map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 4,
                                ),
                                child: SyncTile(task: e, settings: db.settings),
                              ),
                            ),
                          ] else if (groupKey == 'today' &&
                              !showCompletedTasks) ...[
                            const SizedBox(height: 16),

                            ///if(!showCompletedTasks)
                            Text(
                              'Calendar Events',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "No calendar events today",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 30),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  bool _isCalEventForToday(CalendarEvent task) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    DateTime? storedDate = DateTimeUtilsHelper.combineDateAndTime(
      DateTimeUtilsHelper.parseDate(task.dueDate),
      DateTimeUtilsHelper.parseTime(task.dueTime!),
    );
    storedDate = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(storedDate);
    if (storedDate == null) return false;
    final storedDay = DateTime.utc(
      storedDate.year,
      storedDate.month,
      storedDate.day,
    );

    if (storedDay.isAfter(today)) return false;
    switch (task.repeatType?.toLowerCase() ?? 'none') {
      case 'daily':
        return true;
      case 'weekly':
        return storedDate.weekday == now.weekday;
      case 'monthly':
        return storedDate.day == now.day;
      case 'yearly':
        return storedDate.month == now.month && storedDate.day == now.day;
      default:
        return storedDay.isAtSameMomentAs(today);
    }
  }

  Map<String, List<Task>> getUpcomingTasksWithinHotPeriod(List<Task> toDoList) {
    final now = DateTime.now().toUtc();
    final twoHoursLater = now.add(const Duration(hours: 2));
    final oneHourLater = now.add(const Duration(hours: 1));

    final Map<String, List<Task>> result = {'High': [], 'Medium': []};

    for (var task in toDoList) {
      final String priority = task.priority;
      final String dueDateStr = task.dueDate ?? '';
      final String dueTimeStr = task.dueTime ?? '';

      // Fix: remove force-unwrap — skip malformed dates instead of crashing
      DateTime? dueDate = DateTime.tryParse('$dueDateStr $dueTimeStr');
      if (dueDate == null) continue;

      dueDate = DateTime.utc(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueDate.hour,
        dueDate.minute,
        dueDate.second,
      );

      if (dueDate.isAfter(now) && !task.completed) {
        if (priority == 'High' && dueDate.isBefore(twoHoursLater)) {
          result['High']!.add(task);
        } else if (priority == 'Medium' && dueDate.isBefore(oneHourLater)) {
          result['Medium']!.add(task);
        }
      }
    }

    // Fix: use null instead of Colors.white as the "no warning" sentinel
    if (result['High']!.isNotEmpty) {
      warningColor = Colors.red;
    } else if (result['Medium']!.isNotEmpty) {
      warningColor = const Color.fromARGB(255, 255, 193, 59);
    } else {
      warningColor = null;
    }

    return result;
  }

  void showPendingPriorityTasksDialog(BuildContext context) {
    final List<Task> highPriorityTasks = hotTasks['High'] ?? [];
    final List<Task> mediumPriorityTasks = hotTasks['Medium'] ?? [];

    if (highPriorityTasks.isEmpty && mediumPriorityTasks.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final cs = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              // Fix: theme-aware surface color instead of hardcoded grey[100]
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Pending Priority Tasks',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (highPriorityTasks.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              // Fix: theme errorContainer instead of red[100]
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'High Priority',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.error,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...highPriorityTasks.map(
                            (task) => Card(
                              // Fix: theme-aware card instead of red[50]
                              color: cs.errorContainer.withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.priority_high,
                                  color: cs.error,
                                ),
                                title: Text(
                                  task.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Fix: formatted date instead of raw string
                                subtitle: Text(
                                  'Due: ${_formatDueDate(task.dueDate, task.dueTime)}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (mediumPriorityTasks.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              // Fix: theme-aware amber tint instead of orange[100]
                              color: const Color(
                                0xFFFFB300,
                              ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Medium Priority',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFB300),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...mediumPriorityTasks.map(
                            (task) => Card(
                              color: const Color(
                                0xFFFFB300,
                              ).withValues(alpha: 0.1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.low_priority,
                                  color: Color(0xFFFFB300),
                                ),
                                title: Text(
                                  task.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Due: ${_formatDueDate(task.dueDate, task.dueTime)}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Calendar sync ─────────────────────────────────────────────────────────

  Future<void> importViewOnly() async {
    final syncProvider = context.read<CalendarSyncProvider>();

    final String localCalendarId = db.syncToCalendars["local"];
    final String outlookCalendarId = db.syncToCalendars["outlook"];
    final String googleCalendarId = db.syncToCalendars["google"];

    if (localCalendarId == "none" &&
        outlookCalendarId == "none" &&
        googleCalendarId == "none") {
      return;
    }

    syncProvider.startSync();

    if (localCalendarId != "none") {
      try {
        await LocalCalendarService.syncTasksFromCalendar(db);
        syncProvider.updateProgress(0.3);
      } catch (e) {
        print("Failed to sync local calendars: $e");
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    if (outlookCalendarId != "none") {
      try {
        await OutlookCalendarService.syncTasksFromCalendar(db);
        syncProvider.updateProgress(0.5);
      } catch (e) {
        print("Failed to sync outlook calendars: $e");
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    if (googleCalendarId != "none") {
      try {
        await GoogleCalendarService.syncTasksFromCalendars(db);
        syncProvider.updateProgress(0.8);
      } catch (e) {
        print("Failed to sync google calendars: $e");
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    syncProvider.finishSync();

    // Fix: guard against widget being disposed after the awaits above
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Calendar synced successfully"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
