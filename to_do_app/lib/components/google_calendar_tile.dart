import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/sync_problem_dialog.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/pages/google_calendar_sync_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/app_startup.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/sync_problem.dart';

import 'package:to_do_app/components/sync_provider_card.dart';

import 'package:to_do_app/components/brand_logo.dart';

class GoogleCalendarTile extends StatefulWidget {
  final ToDoDataBase db;

  const GoogleCalendarTile({super.key, required this.db});

  @override
  State<GoogleCalendarTile> createState() => _GoogleCalendarTileState();
}

class _GoogleCalendarTileState extends State<GoogleCalendarTile> {
  bool _isLoading = false;

  static const _brandColor = Color(0xFF4285F4);

  Future<void> _fetchAndNavigate() async {
    setState(() => _isLoading = true);
    SyncProblem? problem;
    try {
      problem = await _connect();
    } catch (e, st) {
      debugPrint('Google Calendar connect failed: $e\n$st');
      problem = SyncProblem.classify(e, SyncService.googleCalendar);
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

    // The silent restore started in main() may still be running; a second
    // overlapping sign-in call on the platform plugin fails.
    await AppStartup.ready;
    if (!mounted) return null;

    // Reuses a sign-in done anywhere else; only prompts if there is none.
    final user = await GoogleAuthService.ensureSignedIn(auth: authProvider);
    if (!mounted) return null;
    if (user == null) {
      return SyncProblem.classify(
        GoogleAuthService.lastError,
        SyncService.googleCalendar,
      );
    }

    // The account is signed in but no usable token could be built.
    if (!await GoogleAuthService.ensureApisReady()) {
      return SyncProblem.classify(
        GoogleAuthService.lastError ?? const NotSignedInException(),
        SyncService.googleCalendar,
      );
    }
    final calendarAPI = GoogleAuthService.calendarApi!;
    final calendars = await calendarAPI.calendarList.list();
    if (!mounted) return null;

    if (calendars.items?.isNotEmpty == true) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => GoogleCalendarSyncPage(
                calendars: calendars.items ?? [],
                db: widget.db,
                accountName: GoogleAuthService.currentUser?.email ?? "Unknown",
                calendarAPI: calendarAPI,
              ),
        ),
      );
      if (mounted) setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Google calendars found on this account."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return null;
  }

  Future<void> _disableSync() async {
    widget.db.syncToCalendars["google"] = "none";
    widget.db.viewOnlyCalendars["google"] = {};
    // Only the sync settings changed; the next launch clears the cached events.
    widget.db.saveSyncToCalendars();
    widget.db.saveViewOnlyCalendars();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSyncActive =
        widget.db.syncToCalendars["google"] != "none" ||
        widget.db.viewOnlyCalendars["google"]!.isNotEmpty;
    final auth = context.watch<AuthProvider>();
    final String? connectedEmail = auth.email.isNotEmpty ? auth.email : null;

    return SyncProviderCard(
      name: "Google Calendar",
      brandIcon: BrandIcon.googleCalendar,
      brandColor: _brandColor,
      connected: isSyncActive,
      loading: _isLoading,
      status:
          isSyncActive && connectedEmail != null
              ? "Connected as $connectedEmail"
              : (isSyncActive ? "Connected" : "Not connected"),
      description:
          "Push tasks to Google Calendar as events. Changes sync automatically.",
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
