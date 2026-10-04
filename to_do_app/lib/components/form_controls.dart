import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';

/// A row inside a grouped options card: icon, label, trailing control.
/// Shared by the task sheet and the Import .ics page (Figma "Options").
class OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  const OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: context.appColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A bordered card that stacks [rows] with 1px dividers between them.
class OptionsCard extends StatelessWidget {
  final List<Widget> rows;
  const OptionsCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 1, thickness: 1, color: colors.outline),
          ],
        ],
      ),
    );
  }
}

/// Outlined drop-down: shows the value and opens a menu of [options].
class DropChip extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const DropChip({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: '',
      itemBuilder:
          (_) => [
            for (final o in options)
              PopupMenuItem<String>(value: o, child: Text(o)),
          ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

/// Selectable pill (priority / category): outlined when idle, amber outline
/// and soft fill when selected.
class SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? dotColor;
  final bool center;
  final VoidCallback onTap;
  const SheetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
    this.center = false,
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
            color: selected ? kAccent : colors.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: center ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
