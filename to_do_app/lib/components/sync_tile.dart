import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class SyncTile extends StatelessWidget {
  final CalendarEvent task;
  final AppSettings settings;
  const SyncTile({
    super.key,
    required this.task,
    this.settings = const AppSettings(),
  });

  static const _googleColor = Color(0xFF4285F4);
  static const _outlookColor = Color(0xFF0078D4);
  static const _localColor = Color(0xFF00897B);
  static const _defaultColor = Color(0xFF9E9E9E);

  Color _accentColor(String source) {
    final s = source.toLowerCase();
    if (s.contains('google')) return _googleColor;
    if (s.contains('outlook')) return _outlookColor;
    if (s.contains('local')) return _localColor;
    return _defaultColor;
  }

  String _providerName(String source) {
    final s = source.toLowerCase();
    if (s.contains('google')) return 'Google Calendar';
    if (s.contains('outlook')) return 'Outlook Calendar';
    if (s.contains('local')) return 'Device Calendar';
    return 'Calendar';
  }

  String _formatTime(String? date, String? time) {
    if (time == null || time == '00:00' || time.isEmpty) return '';
    if (date == '0000-00-00' || date == null) return '';
    try {
      final utcDateTime = DateTimeUtilsHelper.utcDatetimeFromStrings(
        date,
        time,
      );
      final localDateTime = utcDateTime.toLocal();
      return DateTimeUtilsHelper.displayTime(localDateTime, settings);
    } catch (_) {
      return time;
    }
  }

  Future<void> _openCalendarEvent() async {
    final String eventId = task.eventId;
    if (eventId.isNotEmpty) {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'content://com.android.calendar/events/$eventId',
      );
      await intent.launch();
      return;
    }
    final Uri fallback = Uri.parse('content://com.android.calendar/time/');
    if (await canLaunchUrl(fallback)) await launchUrl(fallback);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = context.appColors.muted;
    final String name = task.name;
    final String source = task.source;
    final String timeStr = _formatTime(task.dueDate, task.dueTime);
    final Color accent = _accentColor(source);
    final String subtitle =
        timeStr.isEmpty
            ? _providerName(source)
            : '$timeStr · ${_providerName(source)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCalendarEvent,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              // Calendar colour bar
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
