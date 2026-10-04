import 'package:flutter/material.dart';

class EditCategoriesDialog extends StatefulWidget {
  final void Function(List<String>, List<String>, Map<String, String>)
  onCategoryChanged;
  final List<String> hidingCategories;
  final List<String> categoryTypes;
  const EditCategoriesDialog({
    super.key,
    required this.hidingCategories,
    required this.onCategoryChanged,
    required this.categoryTypes,
  });

  @override
  State<EditCategoriesDialog> createState() => _EditCategoriesDialogState();
}

class _EditCategoriesDialogState extends State<EditCategoriesDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late TextEditingController newCategoryController;

  bool categoryAddedDeleted = false;
  late List<String> hidingCategories;

  Map<String, String> editedCategories = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    newCategoryController = TextEditingController();
    hidingCategories = widget.hidingCategories;
    //newCategoryController
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), // <-- radius here
      ),
      title: Column(
        children: [
          SizedBox(height: 40),
          Text(
            'Manage Categories',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add category field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newCategoryController,
                    decoration: const InputDecoration(
                      hintText: 'New category name',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    if (newCategoryController.text.trim().isEmpty) return;
                    categoryAddedDeleted = true;
                    setState(() {
                      widget.categoryTypes.add(
                        newCategoryController.text.trim(),
                      );
                    });
                    // onAdd(
                    //   newCategoryController
                    //       .text
                    //       .trim(),
                    // );
                    newCategoryController.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Category list
            Expanded(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: widget.categoryTypes.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = widget.categoryTypes.removeAt(oldIndex);
                    widget.categoryTypes.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final category = widget.categoryTypes[index];

                  if (category == "None")
                    return SizedBox.shrink(key: ValueKey(category));

                  return Padding(
                    key: ValueKey(category),
                    // Required for reorderable lists
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(category),

                        //subtitle: Text("$category tasks"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                hidingCategories.contains(category)
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              tooltip:
                                  hidingCategories.contains(category)
                                      ? 'Unhide category'
                                      : 'Hide category',
                              onPressed: () {
                                setState(() {
                                  if (hidingCategories.contains(category)) {
                                    hidingCategories.remove(category);
                                  } else {
                                    hidingCategories.add(category);
                                  }
                                });
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'Edit') {
                                  TextEditingController editController =
                                      TextEditingController(
                                        text: widget.categoryTypes[index],
                                      );

                                  await showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text('Edit Category'),
                                          content: TextField(
                                            controller: editController,
                                            decoration: const InputDecoration(
                                              hintText: 'Category name',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                String oldName =
                                                    widget.categoryTypes[index];
                                                String newName =
                                                    editController.text.trim();
                                                if (newName.isNotEmpty) {
                                                  setState(() {
                                                    widget.categoryTypes[index] =
                                                        newName;
                                                    editedCategories[oldName] =
                                                        newName;
                                                  });
                                                }
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                  );
                                } else if (value == 'Delete') {
                                  categoryAddedDeleted = true;
                                  setState(() {
                                    widget.categoryTypes.removeAt(index);
                                  });
                                } else if (value == 'Hide') {
                                  setState(() {
                                    hidingCategories.add(
                                      widget.categoryTypes[index],
                                    );
                                  });
                                } else if (value == 'Unhide') {
                                  setState(() {
                                    hidingCategories.remove(
                                      widget.categoryTypes[index],
                                    );
                                  });
                                }
                              },
                              itemBuilder: (context) {
                                final isHidden = hidingCategories.contains(
                                  category,
                                );
                                return [
                                  const PopupMenuItem(
                                    value: 'Edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: isHidden ? 'Unhide' : 'Hide',
                                    child: Text(isHidden ? 'Unhide' : 'Hide'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'Delete',
                                    child: Text('Delete'),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onCategoryChanged(
              widget.categoryTypes,
              hidingCategories,
              editedCategories,
            );

            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
