// import 'package:flutter/material.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// //import 'package:intl/intl.dart';
// import 'package:to_do_app/components/create_task_sheet.dart';
// import 'package:to_do_app/utils/date_time_utils.dart';

// class TaskTile extends StatefulWidget {
//   final int index;
//   final Function(int, Map<String, dynamic>)? onEdit;
//   final bool isStarred;
//   final String taskName;
//   final bool taskCompleted;
//   final Function(int, bool?)? onChanged;
//   final Function(int)? deleteFunction;
//   final String taskNote;
//   final DateTime? dueTime;
//   final DateTime? dueDate;
//   final String taskCategory;
//   final String taskPriority;
//   final String repeatType;
//   final int remainderAmount;
//   final String remainderType;
//   final List<String> repeatTypes;
//   final List<String> priorityTypes;
//   final List<String> remainderTypes;
//   final List<String> categoryTypes;
//   final List<Map<String, dynamic>>? initialSubtasks;
//   const TaskTile({
//     super.key,
//     required this.initialSubtasks,
//     required this.index,
//     required this.isStarred,
//     required this.onEdit,
//     required this.taskName,
//     required this.taskCompleted,
//     required this.onChanged,
//     required this.deleteFunction,
//     required this.repeatTypes,
//     required this.priorityTypes,
//     required this.remainderTypes,
//     required this.categoryTypes,
//     this.taskNote = "",
//     this.dueTime,
//     this.dueDate,
//     this.taskCategory = "None",
//     this.taskPriority = "Low",
//     this.repeatType = "daily",
//     this.remainderAmount = 0,
//     this.remainderType = "minutes",
//   });

//   @override
//   State<TaskTile> createState() => _TaskTileState();
// }

// class _TaskTileState extends State<TaskTile> {
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.only(bottom: 0),
//         child: Slidable(
//           endActionPane: ActionPane(
//             motion: StretchMotion(),
//             children: [
//               SlidableAction(
//                 onPressed /*calls function with context as input*/ :
//                     (context) => widget.deleteFunction?.call(widget.index),
//                 icon: Icons.delete,
//                 backgroundColor: Colors.red.shade300,
//                 borderRadius: BorderRadius.circular(12),

//                 padding: const EdgeInsets.symmetric(vertical: 50),
//               ),
//             ],
//           ),
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Theme.of(context).colorScheme.secondary,
//               borderRadius: BorderRadius.circular(15),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 5,
//                   offset: const Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Checkbox(
//                   value: widget.taskCompleted, // bool variable from state
//                   onChanged: (value) {
//                     widget.onChanged?.call(widget.index, value);
//                   },

//                   activeColor: Theme.of(context).colorScheme.onSecondary,
//                 ),
//                 const SizedBox(width: 20),

//                 Expanded(
//                   child: Text(
//                     widget.taskName,
//                     style: TextStyle(
//                       color: Theme.of(context).colorScheme.onSurface,
//                       fontSize: 18,
//                     ),
//                   ),
//                 ),
//                 (widget.isStarred)
//                     ? Icon(
//                       Icons.star,
//                       color: Theme.of(context).colorScheme.primary,
//                     )
//                     : Expanded(child: Text("")),
//                 PopupMenuButton<String>(
//                   borderRadius: BorderRadius.circular(20),
//                   icon: Icon(Icons.more_vert),
//                   onSelected: (value) {
//                     if (value == "Star") {
//                       widget.onEdit?.call(widget.index, {
//                         'isStarred': (!widget.isStarred).toString(),
//                         'taskName': widget.taskName,
//                         'taskNote': widget.taskNote,
//                         'dueDate': DateTimeUtilsHelper.formatDate(
//                           widget.dueDate,
//                         ),
//                         'dueTime': DateTimeUtilsHelper.formatTime(
//                           widget.dueTime,
//                         ),
//                         'taskCategory': widget.taskCategory,
//                         'taskPriority': widget.taskPriority,
//                         'repeatType': widget.repeatType,
//                         'remainderAmount': widget.remainderAmount,
//                         'remainderType': widget.remainderType,
//                         'createdAt': DateTime.now().toString(),
//                         'subTasks': widget.initialSubtasks ?? [],
//                       });
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(
//                             '${widget.taskName} was ${!widget.isStarred ? "starred" : "unstarred"}',
//                           ),
//                         ),
//                       );
//                     }

//                     if (value == "Edit") {
//                       showModalBottomSheet(
//                         isScrollControlled: true,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.vertical(
//                             top: Radius.circular(20),
//                           ),
//                         ),
//                         backgroundColor: Colors.transparent,
//                         context: context,
//                         builder:
//                             (contex) => CreateTaskSheet(
//                               initialSubtasks: widget.initialSubtasks ?? [],
//                               buttonText: "Save changes",
//                               taskNameController: TextEditingController(
//                                 text: widget.taskName,
//                               ),
//                               taskNoteController: TextEditingController(
//                                 text: widget.taskNote,
//                               ),
//                               initialCategory: widget.taskCategory,
//                               initialPriority: widget.taskPriority,
//                               initialRepeatType: widget.repeatType,
//                               initialRemainderAmount: widget.remainderAmount,
//                               initialRemainderType: widget.remainderType,
//                               initialDueDate: widget.dueDate,
//                               initialDueTime: widget.dueTime,

//                               remainderAmountController: TextEditingController(
//                                 text: widget.remainderAmount.toString().trim(),
//                               ),
//                               onSave: (taskDetails) {
//                                 if (widget.onEdit != null) {
//                                   widget.onEdit!(widget.index, taskDetails);
//                                 }
//                               },
//                               repeatTypes: widget.repeatTypes,
//                               priorityTypes: widget.priorityTypes,
//                               remainderTypes: widget.remainderTypes,
//                               categoryTypes: widget.categoryTypes,
//                               //selectedDueDate: _selectedDueDate,
//                             ),
//                       );
//                     }
//                   },
//                   itemBuilder:
//                       (context) => [
//                         PopupMenuItem(
//                           value: 'Star',
//                           child:
//                               !widget.isStarred ? Text('Star') : Text('Unstar'),
//                         ),
//                         PopupMenuItem(value: 'Edit', child: Text('Edit')),
//                       ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
