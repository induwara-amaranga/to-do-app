import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/pages/local_calendar_sync_page.dart';
import 'package:to_do_app/services/local_calendar_service.dart';

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
    widget.db.updateDataBase();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSyncActive =
        widget.db.syncToCalendars["local"] != "none" ||
        widget.db.viewOnlyCalendars["local"]!.isNotEmpty;
    final outline = Theme.of(context).colorScheme.outline;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSyncActive ? _brandColor.withValues(alpha: 0.5) : outline,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.secondary,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _brandColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Device Calendar",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isSyncActive ? "Connected" : "Not connected",
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isSyncActive
                                  ? _brandColor
                                  : onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: outline),
          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              "Sync tasks with your device's built-in calendar app.",
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          // Switch
          SwitchListTile(
            title: const Text("Enable sync"),
            value: isSyncActive,
            onChanged:
                _isLoading
                    ? null
                    : (value) async {
                      if (value) {
                        await _handleEnableSync();
                      } else {
                        await _disableSync();
                      }
                    },
            activeColor: Theme.of(context).colorScheme.primary,
            secondary:
                _isLoading
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                    : null,
          ),
          // Manage footer (only when active)
          if (isSyncActive) ...[
            Divider(height: 1, color: outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading ? null : _handleManage,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text("Manage"),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
