import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:provider/provider.dart';
import 'package:to_do_app/components/sync_page_widgets.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/services/google_calendar_service.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';

import 'package:to_do_app/components/brand_logo.dart';

class GoogleCalendarSyncPage extends StatefulWidget {
  final gcal.CalendarApi calendarAPI;
  final List<gcal.CalendarListEntry> calendars;
  final ToDoDataBase db;
  final String accountName;

  const GoogleCalendarSyncPage({
    super.key,
    required this.calendarAPI,
    required this.accountName,
    required this.calendars,
    required this.db,
  });

  @override
  State<GoogleCalendarSyncPage> createState() => _GoogleCalendarSyncPageState();
}

class _GoogleCalendarSyncPageState extends State<GoogleCalendarSyncPage> {

  bool? syncToCalendar = false;
  late Map<String, bool> importCalendars = {};
  late Map<String, bool> syncCalendars = {};
  List<gcal.CalendarListEntry> calendars = [];
  bool isImportLoading = false;
  bool isViewOnlyLoading = false;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    calendars = widget.calendars;
    // Initialize all calendars as unchecked
    importCalendars = {for (var cal in calendars) cal.id!: false};
    syncCalendars = {for (var cal in calendars) cal.id!: false};
    if (widget.db.syncToCalendars["google"] != "none") {
      syncToCalendar = true;
    }
  }

  void _toggleImportCalendar(String calendarId, bool? value) {
    setState(() {
      importCalendars[calendarId] = value ?? true;
    });
  }

  void _toggleSyncCalendar(String calendarId, bool? value) {
    setState(() {
      syncCalendars[calendarId] = value ?? true;
    });
  }

  Future<List<gcal.CalendarListEntry>> _getSelectedCalendars(
    Map<dynamic, dynamic> selectedCalMap,
  ) async {
    final selected =
        calendars.where((cal) => selectedCalMap[cal.id] == true).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No calendars selected")));

      return [];
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${selected.length} calendar(s) selected for sync"),
      ),
    );
    return selected;
  }

  Future<void> _refreshCalendars() async {
    gcal.CalendarList googCalendars =
        await widget.calendarAPI.calendarList.list();

    calendars = googCalendars.items ?? [];
    importCalendars = {for (var cal in calendars) cal.id!: false};
    syncCalendars = {for (var cal in calendars) cal.id!: false};
    if (mounted) setState(() {});
  }

  Future<void> _importSelected() async {
    setState(() {
      isImportLoading = true;
    });
    final selectedImportCalendars = await _getSelectedCalendars(
      importCalendars,
    );
    final gcal.Calendar? toDoCalendar;
    toDoCalendar = await GoogleCalendarService.createOrGetCalendar(calendars);
    if (toDoCalendar == null) {
      if (mounted) setState(() => isImportLoading = false);
      return;
    }

    for (var cal in selectedImportCalendars) {
      await GoogleCalendarService.importEventsToDB(cal.id!, widget.db);
    }
    if (!mounted) return;
    context.read<CalendarSyncProvider>().notify();
    setState(() {
      isImportLoading = false;
    });
  }

  Future<void> _showViewOnly() async {
    setState(() {
      isViewOnlyLoading = true;
    });
    try {
      final selectedSyncCalendars = await _getSelectedCalendars(syncCalendars);

      for (var cal in selectedSyncCalendars) {
        // Mark calendar as synced
        widget.db.viewOnlyCalendars["google"]!.add(cal.id!);

        // Fetch events from this calendar
        final events = await GoogleCalendarService.getEvents(cal.id!);

        await GoogleCalendarService.importViewOnlyEventsToDB(events, widget.db);
      }
      if (!mounted) return;
      context.read<CalendarSyncProvider>().notify();
      setState(() {
        isViewOnlyLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isViewOnlyLoading = false;
        });
      }
    }
  }

  Future<void> _setSyncEnabled(bool value) async {
    setState(() {
      syncToCalendar = value;
    });
    final gcal.Calendar? toDoCalendar;
    if (value) {
      setState(() {
        isSyncing = true;
      });
      toDoCalendar = await GoogleCalendarService.createOrGetCalendar(calendars);
      widget.db.syncToCalendars["google"] = toDoCalendar!.id;
      try {
        await GoogleCalendarService.syncTasksToCalendar(
          widget.db,
          toDoCalendar.id.toString(),
        );
        await GoogleCalendarService.syncTasksFromCalendars(widget.db);
      } catch (_) {}
    } else {
      widget.db.syncToCalendars["google"] = "none";
    }
    widget.db.updateDataBase();
    if (!mounted) return;
    context.read<CalendarSyncProvider>().notify();
    setState(() {
      isSyncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todoCalendarId = widget.db.syncToCalendars["google"];
    return Scaffold(
      appBar: syncAppBar(context, "Sync Google Calendars"),
      body: SyncPageBody(
        children: [
          ProviderAccountCard(
            name: "Google Calendar",
            brandIcon: BrandIcon.googleCalendar,
            subtitle: "Connected as ${widget.accountName}",
          ),
          CalendarSection(
            title: "Import events",
            description:
                "Copy events from these calendars into your task list as editable tasks.",
            actionLabel: "Import",
            loading: isImportLoading,
            onRefresh: _refreshCalendars,
            onApply: _importSelected,
            children: [
              for (final cal in calendars)
                if (cal.id != todoCalendarId)
                  CalendarCheckRow(
                    name: cal.summary ?? 'Unnamed Calendar',
                    account: widget.accountName,
                    checked: importCalendars[cal.id] ?? false,
                    onChanged: (v) => _toggleImportCalendar(cal.id!, v),
                  ),
            ],
          ),
          CalendarSection(
            title: "View-only events",
            description:
                "Show events from these calendars in your task list without importing them.",
            actionLabel: "Show events",
            loading: isViewOnlyLoading,
            onRefresh: _refreshCalendars,
            onApply: _showViewOnly,
            children: [
              for (final cal in calendars)
                CalendarCheckRow(
                  name: cal.summary ?? 'Unnamed Calendar',
                  account: widget.accountName,
                  checked: syncCalendars[cal.id] ?? false,
                  onChanged: (v) => _toggleSyncCalendar(cal.id!, v),
                ),
            ],
          ),
          SyncTasksSection(
            calendarName: "Google Calendar",
            value: syncToCalendar ?? false,
            syncing: isSyncing,
            onChanged: _setSyncEnabled,
          ),
        ],
      ),
    );
  }
}
