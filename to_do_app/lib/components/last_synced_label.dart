import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/themes/app_colors.dart';

/// "Last synced 3 min ago" footer text for the calendar sync tiles.
class LastSyncedLabel extends StatelessWidget {
  const LastSyncedLabel({super.key});

  static String _describe(DateTime? at) {
    if (at == null) return 'Not synced yet';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Last synced just now';
    if (diff.inHours < 1) return 'Last synced ${diff.inMinutes} min ago';
    if (diff.inDays < 1) return 'Last synced ${diff.inHours} h ago';
    return 'Last synced ${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CalendarSyncProvider>();
    return Text(
      sync.isSyncing ? 'Syncing…' : _describe(sync.lastSyncedAt),
      style: TextStyle(fontSize: 12, color: context.appColors.muted),
    );
  }
}
