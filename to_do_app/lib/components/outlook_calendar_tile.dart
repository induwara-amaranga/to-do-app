import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/pages/Outlook_calendar_sync_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/Outlook_calendar_service.dart';
import 'package:to_do_app/services/outlook_sign.dart';
import 'package:to_do_app/services/sync_problem.dart';
import 'package:to_do_app/components/sync_problem_dialog.dart';

import 'package:to_do_app/components/sync_provider_card.dart';

import 'package:to_do_app/components/brand_logo.dart';

class OutlookCalendarTile extends StatefulWidget {
  final ToDoDataBase db;

  const OutlookCalendarTile({super.key, required this.db});

  @override
  State<OutlookCalendarTile> createState() => _OutlookCalendarTileState();
}

class _OutlookCalendarTileState extends State<OutlookCalendarTile> {
  bool _isLoading = false;

  static const _brandColor = Color(0xFF0078D4);

  Future<void> _fetchAndNavigate() async {
    setState(() => _isLoading = true);
    SyncProblem? problem;
    try {
      problem = await _connect();
    } catch (e, st) {
      debugPrint('Outlook Calendar connect failed: $e - $st');
      problem = SyncProblem.classify(e, SyncService.outlookCalendar);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (problem != null && mounted) {
      await showSyncProblem(context, problem, onRetry: _fetchAndNavigate);
    }
  }

  /// Signs in if needed, lists the calendars and opens the sync page.
  /// Returns what went wrong, or null on success.
  Future<SyncProblem?> _connect() async {
    final authProvider = context.read<AuthProvider>();

    // Ensure signed in — silent restore first, interactive if needed
    if (!authProvider.isOutlookSignedIn ||
        OutlookAuthService.accessToken == null) {
      // initialize() calls init() + acquireTokenSilently() internally
      final silentSuccess = await OutlookAuthService.initialize();

      if (!silentSuccess) {
        // An expired or missing saved sign-in lands here; go straight to the
        // interactive sign-in, which is also the fix the user would be told.
        final token = await OutlookAuthService.signIn();

        if (!mounted) return null;
        if (token == null) {
          return SyncProblem.classify(
            OutlookAuthService.lastError,
            SyncService.outlookCalendar,
          );
        }
      }

      authProvider.setOutlookSignedIn(true);
    }

    final calendars = await OutlookCalendarService.getAllCalendars();
    if (!mounted) return null;

    if (calendars.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => OutlookCalendarSyncPage(
                calendars: calendars,
                db: widget.db,
                accountName: "Outlook Account",
              ),
        ),
      );
      if (mounted) setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Outlook calendars found on this account."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return null;
  }

  Future<void> _disableSync() async {
    widget.db.syncToCalendars["outlook"] = "none";
    widget.db.viewOnlyCalendars["outlook"] = {};
    // Only the sync settings changed; the next launch clears the cached events.
    widget.db.saveSyncToCalendars();
    widget.db.saveViewOnlyCalendars();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSyncActive =
        widget.db.syncToCalendars["outlook"] != "none" ||
        widget.db.viewOnlyCalendars["outlook"]!.isNotEmpty;

    return SyncProviderCard(
      name: "Outlook Calendar",
      brandIcon: BrandIcon.outlook,
      brandColor: _brandColor,
      connected: isSyncActive,
      loading: _isLoading,
      status: isSyncActive ? "Connected" : "Not connected",
      description: "Sync tasks with your Microsoft Outlook calendar.",
      onToggle: (value) async {
        if (value) {
          await _fetchAndNavigate();
        } else {
          await _disableSync();
        }
      },
      onManage: _fetchAndNavigate,
    );
  }
}
