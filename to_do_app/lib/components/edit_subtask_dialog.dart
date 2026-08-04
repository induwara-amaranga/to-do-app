import 'package:flutter/material.dart';

class EditSubTaskDialog extends StatefulWidget {
  final Map<String, dynamic> subtask;
  final Function(Map<String, dynamic>) onSave;

  const EditSubTaskDialog({
    super.key,
    required this.subtask,
    required this.onSave,
  });

  @override
  State<EditSubTaskDialog> createState() => _EditSubTaskDialogState();
}

class _EditSubTaskDialogState extends State<EditSubTaskDialog> {
  late TextEditingController _nameController;
  DateTime? _subDueDate;
  DateTime? _subDueTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subtask["name"]);
    final rawDate = widget.subtask["dueDate"];
    final rawTime = widget.subtask["dueTime"];
    _subDueDate =
        rawDate is String ? DateTime.tryParse(rawDate) : rawDate as DateTime?;
    _subDueTime =
        rawTime is String ? DateTime.tryParse(rawTime) : rawTime as DateTime?;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Subtask"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Subtask Name"),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: _subDueDate ?? DateTime.now(),
              );
              if (picked != null) setState(() => _subDueDate = picked);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _subDueDate != null
                  ? "Due Date: ${_subDueDate!.toLocal().toString().split(' ')[0]}"
                  : "Select Due Date",
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    _subDueTime != null
                        ? TimeOfDay.fromDateTime(_subDueTime!)
                        : TimeOfDay.now(),
              );
              if (picked != null) {
                final now = DateTime.now();
                setState(() {
                  _subDueTime = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    picked.hour,
                    picked.minute,
                  );
                });
              }
            },
            icon: const Icon(Icons.access_time),
            label: Text(
              _subDueTime != null
                  ? "Due Time: ${TimeOfDay.fromDateTime(_subDueTime!).format(context)}"
                  : "Select Due Time",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              widget.onSave({
                "name": _nameController.text,
                "dueDate": _subDueDate?.toIso8601String(),
                "dueTime": _subDueTime?.toIso8601String(),
                "completed": widget.subtask["completed"],
              });
              Navigator.pop(context);
            }
          },
          child: const Text("Save Changes"),
        ),
      ],
    );
  }
}
