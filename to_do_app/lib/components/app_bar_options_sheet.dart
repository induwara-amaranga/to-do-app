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
import 'package:to_do_app/themes/app_colors.dart';

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
    final colors = context.appColors;
    final currentSort = context.watch<SortingProvider>().mode;
    final currentGroup = context.watch<GroupingProvider>().mode;

    String groupLabel(GroupingMode mode) {
      final rawName = mode.toString().split('.').last;
      return rawName == 'Default' ? 'Default' : 'By ${rawName.toLowerCase()}';
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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
                  color: colors.trackOff,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                "View options",
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            _ChipGroup(
              title: "SORT BY",
              children: [
                for (final mode in SortingMode.values)
                  _OptionChip(
                    label: mode.displayName,
                    selected: currentSort == mode,
                    onTap: () => context.read<SortingProvider>().setMode(mode),
                  ),
              ],
            ),
            _ChipGroup(
              title: "GROUP BY",
              children: [
                for (final mode in GroupingMode.values)
                  _OptionChip(
                    label: groupLabel(mode),
                    selected: currentGroup == mode,
                    onTap: () => context.read<GroupingProvider>().setMode(mode),
                  ),
              ],
            ),

            Divider(height: 1, thickness: 1, color: colors.outline),

            // Navigation actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.filter_list_rounded,
                    title: "Filter tasks",
                    onTap: () => _showFilter(context),
                  ),
                  const SizedBox(height: 2),
                  _ActionRow(
                    icon: Icons.label_outline_rounded,
                    title: "Manage categories",
                    onTap: () => _showCategories(context),
                  ),
                  const SizedBox(height: 2),
                  _ActionRow(
                    icon: Icons.schedule_rounded,
                    title: "Saved timetables",
                    onTap:
                        () => _navigateTo(context, const SavedTimetablesPage()),
                  ),
                  const SizedBox(height: 2),
                  _ActionRow(
                    icon: Icons.sync_rounded,
                    title: "Sync with calendar",
                    onTap: () => _navigateTo(context, CalenderSyncPage(db: db)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled wrap of [_OptionChip]s (SORT BY / GROUP BY).
class _ChipGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ChipGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

/// Selectable pill: outlined when idle, amber outline + soft fill + check
/// when selected.
class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? context.appColors.accent : colors.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: context.appColors.accent),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation row: amber icon tile, title, chevron.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: context.appColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
