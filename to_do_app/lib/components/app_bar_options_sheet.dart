import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/edit_categories_dialog.dart';
import 'package:to_do_app/components/task_filter.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/pages/calender_sync_page.dart';
import 'package:to_do_app/pages/filtered_tasks_page.dart';
import 'package:to_do_app/pages/saved_timetables_page.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';

class AppBarOptionsSheet extends StatelessWidget {
  final ToDoDataBase db;
  final List<String> categoryTypes;
  final List<String> categoriesAndPriorities;
  final void Function(List<String>, List<String>, Map<String, String>)
  onCategoryChanged;
  final List<String> hidingCategories;
  final Function(int, bool?)? onChanged;
  final Function(int)? deleteFunction;
  final void Function(int, dynamic) onTaskChanged;
  final BuildContext parentContext;

  const AppBarOptionsSheet({
    required this.db,
    required this.categoryTypes,
    required this.categoriesAndPriorities,
    required this.onCategoryChanged,
    required this.hidingCategories,
    required this.onChanged,
    required this.deleteFunction,
    required this.onTaskChanged,
    required this.parentContext,
  });

  void _navigateTo(BuildContext sheetCtx, Widget page) {
    Navigator.pop(sheetCtx);
    Navigator.push(parentContext, MaterialPageRoute(builder: (_) => page));
  }

  void _showFilter(BuildContext sheetCtx) {
    Navigator.pop(sheetCtx);
    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogContext) {
        return TaskFilter(
          onApply: (filterData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.push(
                parentContext,
                MaterialPageRoute(
                  builder:
                      (_) => Filteredtaskspage(
                        categoryTypes: categoryTypes,
                        deleteFunction: deleteFunction,
                        onChanged: onChanged,
                        onTaskChanged: onTaskChanged,
                        filterData: filterData,
                        toDoList: db.toDoList,
                        settings: db.settings,
                      ),
                ),
              );
            });
          },
          categoriesAndPriorities: categoriesAndPriorities,
          showCompleted: true,
          showPending: true,
          highPriorityOnly: true,
          selectedFilter: "Selected_dates",
          selectedDueDate: null,
        );
      },
    );
  }

  void _showCategories(BuildContext sheetCtx) {
    Navigator.pop(sheetCtx);
    showDialog(
      context: parentContext,
      builder:
          (_) => EditCategoriesDialog(
            hidingCategories: hidingCategories,
            onCategoryChanged: onCategoryChanged,
            categoryTypes: categoryTypes,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentSort = context.watch<SortingProvider>().mode;
    final currentGroup = context.watch<GroupingProvider>().mode;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Sheet title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              "View options",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sort by
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "SORT BY",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children:
                  SortingMode.values.map((mode) {
                    final isSelected = currentSort == mode;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(mode.displayName),
                      onSelected:
                          (_) => context.read<SortingProvider>().setMode(mode),
                      selectedColor: colorScheme.primaryContainer,
                      checkmarkColor: colorScheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color:
                            isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Group by
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "GROUP BY",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children:
                  GroupingMode.values.map((mode) {
                    final isSelected = currentGroup == mode;
                    final rawName = mode.toString().split('.').last;
                    final label =
                        rawName == 'Default'
                            ? 'Default'
                            : 'By ${rawName.toLowerCase()}';
                    return FilterChip(
                      selected: isSelected,
                      label: Text(label),
                      onSelected:
                          (_) => context.read<GroupingProvider>().setMode(mode),
                      selectedColor: colorScheme.primaryContainer,
                      checkmarkColor: colorScheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color:
                            isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: colorScheme.outlineVariant),

          // Navigation actions
          ListTile(
            leading: Icon(
              Icons.filter_list_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            title: const Text("Filter tasks"),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showFilter(context),
          ),
          ListTile(
            leading: Icon(
              Icons.label_outline_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            title: const Text("Manage categories"),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showCategories(context),
          ),
          ListTile(
            leading: Icon(
              Icons.schedule_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            title: const Text("Saved timetables"),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _navigateTo(context, const SavedTimetablesPage()),
          ),
          ListTile(
            leading: Icon(
              Icons.sync_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            title: const Text("Sync with calendar"),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _navigateTo(context, CalenderSyncPage(db: db)),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
