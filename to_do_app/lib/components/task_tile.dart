import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lottie/lottie.dart';
import 'package:to_do_app/components/create_task_sheet.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

import 'package:to_do_app/themes/app_colors.dart';

class TaskTile extends StatefulWidget {
  final int index;
  final VoidCallback disableCompleted;
  final Function(int, Map<String, dynamic>)? onEdit;
  final bool isStarred;
  final String taskName;
  final bool taskCompleted;
  final Function(int, bool?)? onChanged;
  final Function(int)? deleteFunction;
  final String taskNote;
  final DateTime? dueTime;
  final DateTime? dueDate;
  final String taskCategory;
  final String taskPriority;
  final String repeatType;
  final String source;
  final int remainderAmount;
  final String remainderType;
  final List<String> repeatTypes;
  final List<String> priorityTypes;
  final List<String> remainderTypes;
  final List<String> categoryTypes;
  final List<Map<String, dynamic>>? initialSubtasks;
  final bool playCompletionTone;
  final bool playCompletionAnimation;
  final AppSettings settings;

  const TaskTile({
    super.key,
    required this.source,
    required this.disableCompleted,
    required this.initialSubtasks,
    required this.index,
    required this.isStarred,
    required this.onEdit,
    required this.taskName,
    required this.taskCompleted,
    required this.onChanged,
    required this.deleteFunction,
    required this.repeatTypes,
    required this.priorityTypes,
    required this.remainderTypes,
    required this.categoryTypes,
    this.taskNote = "",
    this.dueTime,
    this.dueDate,
    this.taskCategory = "None",
    this.taskPriority = "Low",
    this.repeatType = "daily",
    this.remainderAmount = 0,
    this.remainderType = "minutes",
    this.playCompletionTone = true,
    this.playCompletionAnimation = true,
    this.settings = const AppSettings(),
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  late bool _completed; // For animation when marking as completed
  bool _isExpanded = false;
  bool _removeTile = false;

  // One shared player for every tile. A per-tile `AudioPlayer()` field holds a
  // native audio resource for the tile's whole lifetime, and tiles are created
  // and thrown away constantly as the list scrolls — with no dispose() to
  // release them. Only one completion tone can be audible at a time anyway.
  static final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showStars = false;

  void _playCheckSound() async {
    await _audioPlayer.play(AssetSource('sounds/success.mp3'));
  }

  void _playStarAnimation() {
    setState(() => _showStars = true);
    Future.delayed(
      Duration(seconds: 1),
      // The lazily-built list may dispose this tile within that second.
      () {
        if (mounted) setState(() => _showStars = false);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _completed = widget.taskCompleted;
  }

  @override
  void didUpdateWidget(covariant TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tiles are keyed by task identity now, so the same State can outlive a
    // completion toggle made elsewhere (e.g. undo). Re-sync from the task.
    if (oldWidget.taskCompleted != widget.taskCompleted) {
      _completed = widget.taskCompleted;
      _removeTile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSize(
        //alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic, // super smooth easing
        //animationStyle: AnimationStyle(curve: Curves.easeInOutCubic),
        child: Container(
          width: _removeTile ? 360 : double.infinity,
          //height: 85,
          //margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          //padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Slidable(
            endActionPane: ActionPane(
              motion: const StretchMotion(),
              children: [
                SlidableAction(
                  onPressed:
                      (context) => widget.deleteFunction?.call(widget.index),
                  icon: Icons.delete,
                  backgroundColor: Colors.red.shade300,
                  borderRadius: BorderRadius.circular(12),
                  //padding: const EdgeInsets.symmetric(vertical: 50),
                ),
              ],
            ),
            child: Material(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(15),
              child: ExpansionTile(
                initiallyExpanded: _isExpanded,
                onExpansionChanged:
                    (expanded) => setState(() => _isExpanded = expanded),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                title: Row(
                  children: [
                    Stack(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(
                            4,
                          ), // optional, matches checkbox
                          onTap: () {
                            bool newValue = !widget.taskCompleted;
                            setState(() {
                              // widget.taskCompleted = newValue;
                            });
                            widget.onChanged?.call(widget.index, newValue);
                          },
                          child: Checkbox(
                            value: _completed,
                            side: BorderSide(
                              color: context.appColors.muted,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                            onChanged: (value) async {
                              if (value == true) {
                                widget.disableCompleted.call();
                                // 1️⃣ Update local state immediately so checkmark is visible
                                setState(() {
                                  _completed =
                                      true; // create this local variable below
                                  _removeTile = true;
                                });
                                if (widget.playCompletionTone) {
                                  _playCheckSound();
                                }
                                if (widget.playCompletionAnimation) {
                                  _playStarAnimation();
                                }

                                // 2️⃣ Wait for UI to repaint
                                await Future.delayed(
                                  const Duration(milliseconds: 1000),
                                );

                                // 3️⃣ Then call parent to actually remove the tile
                                widget.onChanged?.call(widget.index, value);
                                widget.disableCompleted.call();
                              } else {
                                widget.disableCompleted.call();
                                // 1️⃣ Update local state immediately so checkmark is visible
                                setState(() {
                                  _completed =
                                      false; // create this local variable below
                                  //widget.taskCompleted = false;
                                  _removeTile = true;
                                });

                                // 2️⃣ Wait for UI to repaint
                                await Future.delayed(
                                  const Duration(milliseconds: 1000),
                                );

                                // 3️⃣ Then call parent to actually remove the tile
                                widget.onChanged?.call(widget.index, value);
                                widget.disableCompleted.call();
                              }
                            },

                            activeColor:
                                Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                        if (_showStars)
                          Positioned(
                            top: -22,
                            left: -22,
                            child: Lottie.asset(
                              'assets/lottie/Success1.json',
                              width: 100,
                              height: 80,
                              repeat: false,
                              onLoaded: (composition) {
                                // Optionally handle when the animation is loaded
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.taskName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          decoration:
                              _completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                        ),
                      ),
                    ),
                    if (widget.isStarred) Icon(Icons.star, color: kAccent),
                    PopupMenuButton<String>(
                      borderRadius: BorderRadius.circular(20),
                      icon: const Icon(Icons.more_vert),
                      onSelected: _handleMenuSelection,
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'Star',
                              child:
                                  widget.isStarred
                                      ? const Text('Unstar')
                                      : const Text('Star'),
                            ),
                            const PopupMenuItem(
                              value: 'Edit',
                              child: Text('Edit'),
                            ),
                          ],
                    ),
                  ],
                ),
                // The details (timezone conversion + two date formats) are
                // only computed when the tile is actually expanded, not on
                // every build of every collapsed tile in the list.
                children: [
                  Builder(builder: (context) => _buildDetails(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final localTime = DateTimeUtilsHelper.toLocalUsingTz(
      DateTimeUtilsHelper.combineDateAndTime(widget.dueDate, widget.dueTime),
    );
    return GestureDetector(
      onTap:
          () => showModalBottomSheet(
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            backgroundColor: Colors.transparent,
            context: context,
            builder:
                (context) => CreateTaskSheet(
                  isStarred: widget.isStarred,
                  taskName: widget.taskName,
                  taskNote: widget.taskNote,
                  initialSubtasks: widget.initialSubtasks ?? [],
                  buttonText: "Save changes",

                  initialCategory: widget.taskCategory,
                  initialPriority: widget.taskPriority,
                  initialRepeatType: widget.repeatType,
                  initialRemainderAmount: widget.remainderAmount,
                  initialRemainderType: widget.remainderType,
                  initialDueDate: widget.dueDate,
                  initialDueTime: widget.dueTime,

                  onSave: (taskDetails) {
                    if (widget.onEdit != null) {
                      widget.onEdit!(widget.index, taskDetails);
                    }
                  },
                  repeatTypes: widget.repeatTypes,
                  priorityTypes: widget.priorityTypes,
                  remainderTypes: widget.remainderTypes,
                  categoryTypes: widget.categoryTypes,
                ),
          ),
      child: Column(
        children: [
          const Divider(),
          Text(
            "Source : ${widget.source}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (widget.taskNote.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.note_outlined),
              title: Text(widget.taskNote),
            ),
          if (widget.dueDate != null)
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                "Due Date: ${DateTimeUtilsHelper.displayDateNumeric(localTime, widget.settings)}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          if (widget.dueTime != null)
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(
                "Due Time: ${DateTimeUtilsHelper.displayTime(localTime, widget.settings)}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: Text(
              "Priority: ${widget.taskPriority}",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(
              "Category: ${widget.taskCategory}",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(
              "Repeat: ${widget.repeatType}",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value) {
    if (value == "Star") {
      widget.onEdit?.call(widget.index, {
        'isStarred': (!widget.isStarred).toString(),
        'taskName': widget.taskName,
        'taskNote': widget.taskNote,
        'dueDate': DateTimeUtilsHelper.formatDate(widget.dueDate),
        'dueTime': DateTimeUtilsHelper.formatTime(widget.dueTime),
        'taskCategory': widget.taskCategory,
        'taskPriority': widget.taskPriority,
        'repeatType': widget.repeatType,
        'remainderAmount': widget.remainderAmount,
        'remainderType': widget.remainderType,
        'createdAt': DateTime.now().toString(),
        'subTasks': widget.initialSubtasks ?? [],
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.taskName} was ${!widget.isStarred ? "starred" : "unstarred"}',
          ),
        ),
      );
    } else if (value == "Edit") {
      showModalBottomSheet(
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.transparent,
        context: context,
        builder:
            (context) => CreateTaskSheet(
              isStarred: widget.isStarred,
              taskName: widget.taskName,
              taskNote: widget.taskNote,
              initialSubtasks: widget.initialSubtasks ?? [],
              buttonText: "Save changes",

              initialCategory: widget.taskCategory,
              initialPriority: widget.taskPriority,
              initialRepeatType: widget.repeatType,
              initialRemainderAmount: widget.remainderAmount,
              initialRemainderType: widget.remainderType,
              initialDueDate: widget.dueDate,
              initialDueTime: widget.dueTime,

              onSave: (taskDetails) {
                if (widget.onEdit != null) {
                  widget.onEdit!(widget.index, taskDetails);
                }
              },
              repeatTypes: widget.repeatTypes,
              priorityTypes: widget.priorityTypes,
              remainderTypes: widget.remainderTypes,
              categoryTypes: widget.categoryTypes,
            ),
      );
    }
  }
}
