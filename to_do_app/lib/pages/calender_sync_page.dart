import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/google_calendar_tile.dart';
import 'package:to_do_app/components/local_calendar_tile.dart';
import 'package:to_do_app/components/outlook_calendar_tile.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';

import 'package:to_do_app/themes/app_colors.dart';

class CalenderSyncPage extends StatefulWidget {
  final ToDoDataBase db;
  const CalenderSyncPage({super.key, required this.db});

  @override
  State<CalenderSyncPage> createState() => _CalenderSyncPageState();
}

class _CalenderSyncPageState extends State<CalenderSyncPage> {
  late ToDoDataBase db;

  @override
  void initState() {
    super.initState();
    db = widget.db;
  }

  // Fades and slides each tile in, a little later than the one above it.
  Widget _staggeredEntry(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 120),
      curve: Curves.easeOut,
      child: child,
      builder:
          (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 16),
              child: child,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CalendarSyncProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendar Sync',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: context.appColors.accent,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Row(
              children: [
                Icon(Icons.sync, size: 26, color: context.appColors.accent),
                const SizedBox(width: 10),
                const Text(
                  "Select sync method",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Connect your tasks to a calendar so they appear as events. You can enable multiple providers.",
              style: TextStyle(
                color: context.appColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 38),
            _staggeredEntry(0, LocalCalendarTile(db: db)),
            const SizedBox(height: 16),
            _staggeredEntry(1, GoogleCalendarTile(db: db)),
            const SizedBox(height: 16),
            _staggeredEntry(2, OutlookCalendarTile(db: db)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
