import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:provider/provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/pages/google_calendar_sync_page.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/google_sign.dart';

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
    try {
      final authProvider = context.read<AuthProvider>();

      // Reuses a sign-in done anywhere else; only prompts if there is none.
      final user = await GoogleAuthService.ensureSignedIn(auth: authProvider);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google sign-in was cancelled."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final calendarAPI = GoogleAuthService.calendarApi;

      gcal.CalendarList calendars = gcal.CalendarList();
      if (calendarAPI != null) {
        calendars = await calendarAPI.calendarList.list();
      }

      if (!mounted) return;

      if (calendars.items?.isNotEmpty == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => GoogleCalendarSyncPage(
                  calendars: calendars.items ?? [],
                  db: widget.db,
                  accountName:
                      GoogleAuthService.currentUser?.email ?? "Unknown",
                  calendarAPI: calendarAPI!,
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't connect to Google Calendar. Check your internet and try again.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disableSync() async {
    widget.db.syncToCalendars["google"] = "none";
    widget.db.viewOnlyCalendars["google"] = {};
    widget.db.updateDataBase();
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
