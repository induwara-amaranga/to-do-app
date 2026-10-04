import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/sync_page_widgets.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/services/local_calendar_service.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';

import 'package:to_do_app/components/brand_logo.dart';

class LocalCalendarSyncPage extends StatefulWidget {
  final List<Calendar> calendars;
  final ToDoDataBase db;

  const LocalCalendarSyncPage({
    super.key,
    required this.calendars,
    required this.db,
  });

  @override
  State<LocalCalendarSyncPage> createState() => _LocalCalendarSyncPageState();
}

class _LocalCalendarSyncPageState extends State<LocalCalendarSyncPage> {
  bool? syncToCalendar = false;
  late Map<String, bool> importCalendars = {};
  late Map<String, bool> syncCalendars = {};
  List<Calendar> calendars = [];
  bool isImportLoading = false;
  bool isViewOnlyLoading = false;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Initialize all calendars as unchecked
    calendars = widget.calendars;
    importCalendars = {for (var cal in calendars) cal.id!: false};
    syncCalendars = {for (var cal in calendars) cal.id!: false};
    if (widget.db.syncToCalendars["local"] != "none") {
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

  Future<List<Calendar>> _getSelectedCalendars(
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
    calendars = await LocalCalendarService.getCalendars();
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
    await LocalCalendarService.createNewCalendar(calendars);

    for (var cal in selectedImportCalendars) {
      await LocalCalendarService.importCalendarEventsToDB(
        await LocalCalendarService.getEvents(cal.id),
        widget.db,
      );
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
    final selectedSyncCalendars = await _getSelectedCalendars(syncCalendars);

    for (var cal in selectedSyncCalendars) {
      // Mark calendar as synced
      widget.db.viewOnlyCalendars["local"]!.add(cal.id!);

      // Fetch events from this calendar
      final events = await LocalCalendarService.getEvents(cal.id);

      await LocalCalendarService.importViewOnlyEventsToDB(events, widget.db);
    }
    if (!mounted) return;
    context.read<CalendarSyncProvider>().notify();
    setState(() {
      isViewOnlyLoading = false;
    });
  }

  Future<void> _setSyncEnabled(bool value) async {
    setState(() {
      syncToCalendar = value;
    });
    final Calendar toDoCalendar;
    if (value) {
      setState(() {
        isSyncing = true;
      });
      toDoCalendar = await LocalCalendarService.createNewCalendar(calendars);
      widget.db.syncToCalendars["local"] = toDoCalendar.id!;
      try {
        await LocalCalendarService.syncTasksToCalendar(
          widget.db,
          toDoCalendar.id.toString(),
        );
        await LocalCalendarService.syncTasksFromCalendar(widget.db);
      } catch (_) {}
    } else {
      widget.db.syncToCalendars["local"] = "none";
    }
    // Sync settings plus the tasks (pushing to the calendar records event ids
    // on them). The calendar boxes were already saved by the import itself.
    widget.db.saveSyncToCalendars();
    widget.db.saveViewOnlyCalendars();
    await widget.db.saveToDoList();
    if (!mounted) return;
    context.read<CalendarSyncProvider>().notify();
    setState(() {
      isSyncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todoCalendarId = widget.db.syncToCalendars["local"];
    return Scaffold(
      appBar: syncAppBar(context, "Sync Device Calendars"),
      body: SyncPageBody(
        children: [
          const ProviderAccountCard(
            name: "Device Calendar",
            brandIcon: BrandIcon.deviceCalendar,
            subtitle: "On this device",
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
                    name: cal.name ?? 'Unnamed Calendar',
                    account: cal.accountName ?? 'Unknown account',
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
                  name: cal.name ?? 'Unnamed Calendar',
                  account: cal.accountName ?? 'Unknown account',
                  checked: syncCalendars[cal.id] ?? false,
                  onChanged: (v) => _toggleSyncCalendar(cal.id!, v),
                ),
            ],
          ),
          SyncTasksSection(
            calendarName: "device calendar",
            value: syncToCalendar ?? false,
            syncing: isSyncing,
            onChanged: _setSyncEnabled,
          ),
        ],
      ),
    );
  }
}
