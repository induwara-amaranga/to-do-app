import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/settings.dart';
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

  Widget _providerIcon(String source, Color accent) {
    final s = source.toLowerCase();
    if (s.contains('google')) {
      return Image.asset(
        'assets/images/google/icons8-google-calendar-48-2.png',
        width: 18,
        height: 18,
      );
    }
    if (s.contains('outlook')) {
      return Image.asset(
        'assets/images/outlook/icons8-microsoft-outlook-2025-48-2.png',
        width: 18,
        height: 18,
      );
    }
    return Icon(Icons.calendar_today_rounded, size: 18, color: accent);
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
    final String name = task.name;
    final String source = task.source;
    final String timeStr = _formatTime(task.dueDate, task.dueTime);
    final Color accent = _accentColor(source);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCalendarEvent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Provider icon badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(child: _providerIcon(source, accent)),
                        ),
                        const SizedBox(width: 10),
                        // Name (flexible, can wrap) + time pinned to right
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Trailing open-in-calendar hint
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
