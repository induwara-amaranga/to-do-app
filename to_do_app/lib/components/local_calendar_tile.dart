import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/pages/local_calendar_sync_page.dart';
import 'package:to_do_app/services/local_calendar_service.dart';

import 'package:to_do_app/components/sync_provider_card.dart';

import 'package:to_do_app/components/brand_logo.dart';

class LocalCalendarTile extends StatefulWidget {
  final ToDoDataBase db;

  const LocalCalendarTile({super.key, required this.db});

  @override
  State<LocalCalendarTile> createState() => _LocalCalendarTileState();
}

class _LocalCalendarTileState extends State<LocalCalendarTile> {
  bool _isLoading = false;

  static const _brandColor = Color(0xFF00897B);

  Future<void> _showOpenSettingsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Calendar Access Blocked'),
            content: const Text(
              'Calendar access was denied. Please enable it in Settings to sync your tasks.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  Future<List<Calendar>?> _requestCalendarWithRationale() async {
    if (await LocalCalendarService.hasCalendarPermission()) {
      return _getCalendarsOrNull();
    }

    final status = await Permission.calendarFullAccess.status;
    if (!mounted) return null;

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog();
      return null;
    }

    final bool accepted =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Calendar Access Required'),
                content: const Text(
                  'To sync your tasks with your device calendar, the app needs calendar access.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not Now'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Grant Access'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!accepted) return null;

    final granted = await LocalCalendarService.requestCalendarPermission();
    if (!granted) {
      await _showOpenSettingsDialog();
      return null;
    }

    return _getCalendarsOrNull();
  }

  Future<List<Calendar>?> _getCalendarsOrNull() async {
    final calendars = await LocalCalendarService.getCalendars();
    if (calendars.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No calendars found on this device.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
    return calendars;
  }

  Future<void> _handleEnableSync() async {
    setState(() => _isLoading = true);
    try {
      final calendars = await _requestCalendarWithRationale();
      if (calendars == null) {
        setState(() => _isLoading = false);
        return;
      }
      final toDoCal = await LocalCalendarService.createNewCalendar(calendars);
      widget.db.syncToCalendars["local"] = toDoCal.id!;
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    LocalCalendarSyncPage(calendars: calendars, db: widget.db),
          ),
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't access the device calendar. Please try again.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManage() async {
    setState(() => _isLoading = true);
    try {
      final calendars = await _requestCalendarWithRationale();
      if (calendars == null) return;
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    LocalCalendarSyncPage(calendars: calendars, db: widget.db),
          ),
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't access the device calendar. Please try again.",
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
    widget.db.viewOnlyCalendars["local"] = {};
    widget.db.syncToCalendars["local"] = "none";
    // Only the sync settings changed; the next launch clears the cached events.
    widget.db.saveSyncToCalendars();
    widget.db.saveViewOnlyCalendars();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSyncActive =
        widget.db.syncToCalendars["local"] != "none" ||
        widget.db.viewOnlyCalendars["local"]!.isNotEmpty;

    return SyncProviderCard(
      name: "Device Calendar",
      brandIcon: BrandIcon.deviceCalendar,
      brandColor: _brandColor,
      connected: isSyncActive,
      loading: _isLoading,
      status: isSyncActive ? "Connected" : "Not connected",
      description: "Sync tasks with your device's built-in calendar app.",
      onToggle: (value) async {
        if (value) {
          await _handleEnableSync();
        } else {
          await _disableSync();
        }
      },
      onManage: _handleManage,
    );
  }
}
