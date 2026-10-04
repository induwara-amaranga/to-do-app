import 'package:flutter/material.dart';
import 'package:to_do_app/components/app_toggle.dart';
import 'package:to_do_app/themes/app_colors.dart';

import 'package:to_do_app/components/brand_logo.dart';

/// Shared building blocks for the Device / Google / Outlook calendar sync
/// pages. Layout, type and colours follow the Figma "Provider sync pages".

/// Centred Manrope title on the page surface, accent coloured.
PreferredSizeWidget syncAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) {
  final cs = Theme.of(context).colorScheme;
  return AppBar(
    centerTitle: true,
    backgroundColor: cs.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    iconTheme: IconThemeData(color: cs.onSurface),
    title: Text(
      title,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: context.appColors.accent,
      ),
    ),
    actions: actions,
  );
}

/// Scrollable page body with the standard gutters and 24px section gap.
class SyncPageBody extends StatelessWidget {
  final List<Widget> children;
  const SyncPageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          children[i],
        ],
      ],
    );
  }
}

/// "Google Calendar — Connected as …" card at the top of each page.
class ProviderAccountCard extends StatelessWidget {
  final String name;
  final BrandIcon brandIcon;
  final String subtitle;
  const ProviderAccountCard({
    super.key,
    required this.name,
    required this.brandIcon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          BrandLogo(brandIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled block: heading + description, a refresh button, an action
/// button (spinner while [loading]) and a bordered list of [children].
class CalendarSection extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onApply;
  final List<Widget> children;

  const CalendarSection({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.loading,
    required this.onRefresh,
    required this.onApply,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: colors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: onRefresh,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(Icons.refresh, size: 22, color: colors.muted),
              ),
            ),
            const SizedBox(width: 10),
            if (loading)
              SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: context.appColors.accent,
                  ),
                ),
              )
            else
              InkWell(
                onTap: onApply,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.appColors.onAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            children: [
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No calendars found',
                      style: TextStyle(fontSize: 14, color: colors.muted),
                    ),
                  ),
                ),
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, thickness: 1, color: colors.outline),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One selectable calendar: checkbox, name, account.
class CalendarCheckRow extends StatelessWidget {
  final String name;
  final String account;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const CalendarCheckRow({
    super.key,
    required this.name,
    required this.account,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? context.appColors.accent : null,
                borderRadius: BorderRadius.circular(6),
                border:
                    checked ? null : Border.all(color: colors.muted, width: 2),
              ),
              child:
                  checked
                      ? Icon(
                        Icons.check,
                        size: 16,
                        color: context.appColors.onAccent,
                      )
                      : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account,
                    style: TextStyle(fontSize: 13, color: colors.muted),
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

/// "Sync tasks" block with the enable switch and its explanation.
class SyncTasksSection extends StatelessWidget {
  final String calendarName;
  final bool value;
  final bool syncing;
  final ValueChanged<bool> onChanged;

  const SyncTasksSection({
    super.key,
    required this.calendarName,
    required this.value,
    required this.syncing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sync tasks',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Keep your task list and $calendarName up to date together.',
          style: TextStyle(fontSize: 13, color: colors.muted),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync tasks to calendar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A new calendar "ToDoList" is used for syncing. Only upcoming tasks are synced; past tasks are not.',
                      style: TextStyle(fontSize: 13, color: colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              if (syncing) ...[
                Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              AppToggle(value: value, onChanged: syncing ? null : onChanged),
            ],
          ),
        ),
      ],
    );
  }
}
