import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';

/// Tappable "Calendar Events (n)" heading with a chevron, used by the pages
/// that list calendar events so the user can collapse the list.
class CalendarEventsHeader extends StatelessWidget {
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;
  final EdgeInsetsGeometry padding;

  const CalendarEventsHeader({
    super.key,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Text(
              count > 0 ? 'Calendar Events ($count)' : 'Calendar Events',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.appColors.accent,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: collapsed ? 0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
                size: 22,
                color: context.appColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
