import 'package:flutter/material.dart';
import 'package:to_do_app/components/sync_problem_dialog.dart';
import 'package:to_do_app/services/sync_problem.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/sync_page_widgets.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/services/Outlook_calendar_service.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/services/outlook_sign.dart';

import 'package:to_do_app/components/brand_logo.dart';

class OutlookCalendarSyncPage extends StatefulWidget {
  final List<Map<String, dynamic>> calendars;
  final ToDoDataBase db;
  final String accountName;

  const OutlookCalendarSyncPage({
    super.key,
    required this.accountName,
    required this.calendars,
    required this.db,
  });

  @override
  State<OutlookCalendarSyncPage> createState() =>
      _OutlookCalendarSyncPageState();
}

class _OutlookCalendarSyncPageState extends State<OutlookCalendarSyncPage> {
  bool? syncToCalendar = false;
  late Map<String, bool> importCalendars = {};
  late Map<String, bool> syncCalendars = {};
  List<Map<String, dynamic>> calendars = [];
  bool isImportLoading = false;
  bool isViewOnlyLoading = false;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    calendars = widget.calendars;
    // Initialize all calendars as unchecked
    importCalendars = {for (var cal in calendars) cal["id"]: false};
    syncCalendars = {for (var cal in calendars) cal["id"]: false};
    if (widget.db.syncToCalendars["outlook"] != "none") {
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

  List<Map<String, dynamic>> _getSelectedCalendars(
    Map<dynamic, dynamic> selectedCalMap,
  ) {
    final selected =
        calendars.where((cal) => selectedCalMap[cal["id"]] == true).toList();

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

  Future<void> _report(Object e, {Future<void> Function()? retry}) async {
    debugPrint('Outlook sync step failed: $e');
    if (!mounted) return;
    await showSyncProblem(
      context,
      SyncProblem.classify(e, SyncService.outlookCalendar),
      onRetry: retry,
    );
  }

  Future<void> _refreshCalendars() async {
    try {
      calendars = await OutlookCalendarService.getAllCalendars();
      importCalendars = {for (var cal in calendars) cal["id"]!: false};
      syncCalendars = {for (var cal in calendars) cal["id"]!: false};
      if (mounted) setState(() {});
    } catch (e) {
      await _report(e, retry: _refreshCalendars);
    }
  }

  Future<void> _importSelected() async {
    setState(() {
      isImportLoading = true;
    });
    try {
      final selectedImportCalendars = _getSelectedCalendars(importCalendars);
      await OutlookCalendarService.createOrGetCalendar(calendars);

      for (var cal in selectedImportCalendars) {
        await OutlookCalendarService.importEventsToDB(cal["id"], widget.db);
      }
      if (!mounted) return;
      context.read<CalendarSyncProvider>().notify();
    } catch (e) {
      await _report(e, retry: _importSelected);
    } finally {
      if (mounted) setState(() => isImportLoading = false);
    }
  }

  Future<void> _showViewOnly() async {
    setState(() {
      isViewOnlyLoading = true;
    });
    try {
      final selectedSyncCalendars = _getSelectedCalendars(syncCalendars);

      for (var cal in selectedSyncCalendars) {
        widget.db.viewOnlyCalendars["outlook"]!.add(cal["id"]!);

        await OutlookCalendarService.importViewOnlyEventsToDB(
          cal["id"],
          widget.db,
        );
      }
      if (!mounted) return;
      context.read<CalendarSyncProvider>().notify();
    } catch (e) {
      await _report(e, retry: _showViewOnly);
    } finally {
      if (mounted) setState(() => isViewOnlyLoading = false);
    }
  }

  Future<void> _setSyncEnabled(bool value) async {
    setState(() {
      syncToCalendar = value;
    });
    if (value) {
      setState(() {
        isSyncing = true;
      });
      try {
        final toDoCalendar = await OutlookCalendarService.createOrGetCalendar(
          calendars,
        );
        widget.db.syncToCalendars["outlook"] = toDoCalendar!["id"];
        await OutlookCalendarService.syncTasksToCalendar(
          widget.db,
          toDoCalendar["id"],
        );
        await OutlookCalendarService.syncTasksFromCalendar(widget.db);
      } catch (e) {
        // Leave sync switched off so the toggle matches what is really set up.
        widget.db.syncToCalendars["outlook"] = "none";
        if (mounted) {
          setState(() {
            syncToCalendar = false;
            isSyncing = false;
          });
        }
        await _report(e, retry: () => _setSyncEnabled(true));
        return;
      }
    } else {
      widget.db.syncToCalendars["outlook"] = "none";
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
    final todoCalendarId = widget.db.syncToCalendars["outlook"];
    return Scaffold(
      appBar: syncAppBar(
        context,
        "Sync Outlook Calendars",
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              await OutlookAuthService.signOut();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SyncPageBody(
        children: [
          ProviderAccountCard(
            name: "Outlook Calendar",
            brandIcon: BrandIcon.outlook,
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
                if (cal["id"] != todoCalendarId)
                  CalendarCheckRow(
                    name: cal["name"] ?? 'Unnamed Calendar',
                    account: widget.accountName,
                    checked: importCalendars[cal["id"]] ?? false,
                    onChanged: (v) => _toggleImportCalendar(cal["id"]!, v),
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
                  name: cal["name"] ?? 'Unnamed Calendar',
                  account: widget.accountName,
                  checked: syncCalendars[cal["id"]] ?? false,
                  onChanged: (v) => _toggleSyncCalendar(cal["id"]!, v),
                ),
            ],
          ),
          SyncTasksSection(
            calendarName: "Outlook Calendar",
            value: syncToCalendar ?? false,
            syncing: isSyncing,
            onChanged: _setSyncEnabled,
          ),
        ],
      ),
    );
  }
}
