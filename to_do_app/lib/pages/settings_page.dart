import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/components/ringtone_picker.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/themes/theme_provider.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:to_do_app/components/app_toggle.dart';
//import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════
//  Settings — Flutter port of settings_page.html mockup.
//  Main screen + pushed sub-screens (Notifications, Theme, Widget,
//  Date & Time, Account, About) with colored icon tiles, grouped
//  cards, value badges, toggles and bottom-sheet option pickers.
// ════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
//  Shared building blocks
// ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.appColors.muted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// A rounded card holding a column of rows separated by hairline dividers.
class _Card extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  const _Card({required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: List.generate(children.length, (i) {
            return Column(
              children: [
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.appColors.outline,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ColorIcon extends StatelessWidget {
  final IconData icon;
  // Kept so existing call sites compile; every row now shares the accent tile.
  final String color;
  const _ColorIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.appColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: context.appColors.accent, size: 24),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  final String text;
  const _ValueBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.onSurface.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withAlpha(160),
          fontFeatures: const [],
        ),
      ),
    );
  }
}

/// One settings row: colored icon, title, optional subtitle and a
/// trailing widget (chevron + badge, toggle, dot, check…).
class _Row extends StatelessWidget {
  final IconData icon;
  final String color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _ColorIcon(icon, color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? cs.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (chevron) ...[
              if (trailing != null) const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: context.appColors.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// iOS-style toggle wired to a value + onChanged.
class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return AppToggle(value: value, onChanged: onChanged);
  }
}

/// Bottom-sheet single-choice picker. Returns the chosen value (or null).
Future<String?> _pickOption(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String current,
  bool searchable = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder:
        (ctx) => _OptionSheet(
          title: title,
          options: options,
          current: current,
          searchable: searchable,
        ),
  );
}

/// Sheet body for [_pickOption]. A [StatefulWidget] so the search
/// [TextEditingController] is owned and disposed properly.
class _OptionSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String current;
  final bool searchable;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.searchable,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final query = _controller.text.toLowerCase();
    final visible =
        widget.searchable && query.isNotEmpty
            ? widget.options
                .where((o) => o.toLowerCase().contains(query))
                .toList()
            : widget.options;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            decoration: BoxDecoration(
              color: colors.trackOff,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.outline),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 22, color: colors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: colors.muted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              itemCount: visible.length,
              itemBuilder: (ctx, i) {
                final o = visible[i];
                final selected = o == widget.current;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, o),
                  child: Container(
                    color: selected ? colors.accentSoft : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            o,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  selected ? FontWeight.w500 : FontWeight.w400,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check,
                            size: 22,
                            color: context.appColors.accent,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Common scaffold for pushed sub-screens (back button + title).
class _SubScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SubScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: context.appColors.accent,
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  MAIN SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  final ToDoDataBase db;
  const SettingsPage({super.key, required this.db});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get _s => widget.db.settings;

  //dynamic _get(String key, dynamic fallback) => _s.key ?? fallback;
  void _set(AppSettings updated) {
    setState(() => widget.db.settings = updated);
    widget.db.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final name = auth.displayName.isNotEmpty ? auth.displayName : 'Guest User';
    final email =
        auth.isGoogleSignedIn
            ? (auth.email.isNotEmpty ? auth.email : 'Google Account')
            : 'Local account';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.appColors.accent,
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.nightlight_round,
              color: context.appColors.accent,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Profile card
          _ProfileCard(
            name: name,
            email: email,
            signedIn: auth.isGoogleSignedIn,
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AccountPage(db: widget.db)),
                ),
          ),
          const SizedBox(height: 20),

          // General
          const _SectionLabel('General'),
          _Card(
            children: [
              _Row(
                icon: Icons.notifications_outlined,
                color: 'orange',
                title: 'Notifications & Reminders',
                subtitle: 'Alerts, ringtones, reminders',
                chevron: true,
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5484D),
                    shape: BoxShape.circle,
                  ),
                ),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationsPage(db: widget.db),
                      ),
                    ),
              ),
              _Row(
                icon: Icons.palette_outlined,
                color: 'purple',
                title: 'Theme',
                subtitle: 'Appearance & colors',
                chevron: true,
                trailing: _ValueBadge(isDark ? 'Dark' : 'Light'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ThemePage()),
                    ),
              ),
              _Row(
                icon: Icons.calendar_today_outlined,
                color: 'blue',
                title: 'Sync Calendar',
                subtitle: 'Connect your calendars',
                chevron: true,
                onTap: () => Navigator.pushNamed(context, '/calendarSync'),
              ),
              _Row(
                icon: Icons.dashboard_outlined,
                color: 'teal',
                title: 'Widget',
                subtitle: 'Home screen widget settings',
                chevron: true,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WidgetPage(db: widget.db),
                      ),
                    ),
              ),
              _Row(
                icon: Icons.access_time,
                color: 'green',
                title: 'Date & Time',
                subtitle: 'Format, timezone, first day',
                chevron: true,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DateTimePage(db: widget.db),
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preferences
          const _SectionLabel('Preferences'),
          _Card(
            children: [
              _Row(
                icon: Icons.music_note_outlined,
                color: 'amber',
                title: 'Task Completion Tone',
                subtitle: 'Play sound on task done',
                trailing: _Toggle(
                  _s.completionTone,
                  (v) => _set(_s.copyWith(completionTone: v)),
                ),
              ),
              _Row(
                icon: Icons.auto_awesome,
                color: 'pink',
                title: 'Task Completion Animation',
                subtitle: 'Show confetti animation',
                trailing: _Toggle(
                  _s.completionAnimation,
                  (v) => _set(_s.copyWith(completionAnimation: v)),
                ),
              ),
              _Row(
                icon: Icons.label_outline,
                color: 'indigo',
                title: 'Default Category',
                subtitle: 'For new tasks',
                chevron: true,
                trailing: _ValueBadge(_s.defaultCategory),
                onTap: () async {
                  final v = await _pickOption(
                    context,
                    title: 'Default Category',
                    options: widget.db.categories,
                    current: _s.defaultCategory,
                  );
                  if (v != null) _set(_s.copyWith(defaultCategory: v));
                },
              ),
              _Row(
                icon: Icons.language,
                color: 'teal',
                title: 'Language',
                chevron: true,
                trailing: _ValueBadge(_s.language),
                onTap: () async {
                  final v = await _pickOption(
                    context,
                    title: 'Language',
                    options: const [
                      'English',
                      'Spanish',
                      'French',
                      'German',
                      'Chinese',
                      'Japanese',
                      'Arabic',
                    ],
                    current: _s.language,
                  );
                  if (v != null) _set(_s.copyWith(language: v));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // About
          const _SectionLabel('About'),
          _Card(
            children: [
              _Row(
                icon: Icons.info_outline,
                color: 'gray',
                title: 'About',
                chevron: true,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Manage account button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountPage(db: widget.db),
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.accent,
                foregroundColor: context.appColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text(
                'Manage Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'TaskFlow v3.4.1 · Build 2025.05',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(110)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final bool signedIn;
  final VoidCallback onTap;
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.signedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.appColors.accent,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'G',
                  style: TextStyle(
                    color: context.appColors.onAccent,
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        signedIn ? 'Signed In' : 'Local',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────────
//  NOTIFICATIONS
// ─────────────────────────────────────────────────────────────────

class NotificationsPage extends StatefulWidget {
  final ToDoDataBase db;
  const NotificationsPage({super.key, required this.db});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  AppSettings get _s => widget.db.settings;
  //dynamic _get(String k, dynamic f) => _s[k] ?? f;
  void _set(AppSettings updated) {
    setState(() => widget.db.settings = updated);
    widget.db.saveSettings();
    NotificationService.scheduleDailySummaryNotifications(widget.db);
  }

  // Daily summaries are the first notification feature a user may turn on,
  // so permission is requested here instead of at app start.
  Future<void> _setDailySummary(bool enabled, AppSettings updated) async {
    if (enabled &&
        !await NotificationService.ensureNotificationPermission(
          context,
          rationale:
              'To send your daily summaries, the app needs permission to send notifications.',
        )) {
      return;
    }
    if (!mounted) return;
    _set(updated);
  }

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Notifications',
      children: [
        const _SectionLabel('Reminder Defaults'),
        _Card(
          children: [
            _Row(
              icon: Icons.schedule,
              color: 'orange',
              title: 'Task Reminder Default Time',
              chevron: true,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                width: 50,

                child: TextField(
                  controller: TextEditingController(
                    text: _s.reminderTime.toString(),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) {
                      _set(_s.copyWith(reminderTime: n.toString()));
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(160),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(100),
                        width: 1.5,
                      ),
                    ),
                    // focusedBorder: OutlineInputBorder(
                    //   borderRadius: BorderRadius.circular(8),
                    //   borderSide: BorderSide(
                    //     color: Theme.of(
                    //       context,
                    //     ).colorScheme.onSurface.withAlpha(200),
                    //     width: 2,
                    //   ),
                    // ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ),
            ),
            _Row(
              icon: Icons.notifications_active_outlined,
              color: 'amber',
              title: 'Default Task Reminder Type',
              chevron: true,
              trailing: _ValueBadge(_s.reminderType),
              onTap: () async {
                String? v = await _pickOption(
                  context,
                  title: 'Reminder Type',
                  options: const [
                    'No reminder',
                    'minutes',
                    'hours',
                    'days',
                    'weeks',
                  ],
                  current: _s.reminderType,
                );
                if (v == 'No reminder') v = 'None';
                if (v != null) _set(_s.copyWith(reminderType: v));
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Sounds'),
        _Card(
          children: [
            _Row(
              icon: Icons.music_note_outlined,
              color: 'green',
              title: 'Default Notification Ringtone',
              chevron: true,
              trailing: _ValueBadge(_s.notifName),
              onTap: () async {
                final notifMap = await RingtonePicker.pickNotificationTone(
                  currentUri: _s.notifRingtone,
                );
                if (notifMap != null) {
                  setState(
                    () => _set(_s.copyWith(notifRingtone: notifMap['uri'])),
                  );
                  setState(
                    () => _set(_s.copyWith(notifName: notifMap['name'])),
                  );
                } else {}
              },
            ),
            _Row(
              icon: Icons.alarm,
              color: 'red',
              title: 'Default Alarm Ringtone',
              chevron: true,
              trailing: _ValueBadge(_s.alarmName),
              onTap: () async {
                final alarmMap = await RingtonePicker.pickAlarmTone(
                  currentUri: _s.alarmRingtone,
                );
                if (alarmMap != null) {
                  setState(
                    () => _set(_s.copyWith(alarmRingtone: alarmMap['uri'])),
                  );
                  setState(
                    () => _set(_s.copyWith(alarmName: alarmMap['name'])),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Behavior'),
        _Card(
          children: [
            _Row(
              icon: Icons.lock_outline,
              color: 'blue',
              title: 'Screen Lock Task Reminder',
              subtitle: 'Show on lock screen',
              trailing: _Toggle(
                _s.lockScreenReminder,
                (v) => _set(_s.copyWith(lockScreenReminder: v)),
              ),
            ),
            _Row(
              icon: Icons.view_agenda_outlined,
              color: 'purple',
              title: 'Add Tasks from Notification Bar',
              subtitle: 'Quick-add from pull-down',
              trailing: _Toggle(
                _s.quickAddNotif,
                (v) => _set(_s.copyWith(quickAddNotif: v)),
              ),
            ),
            _Row(
              icon: Icons.list_alt,
              color: 'teal',
              title: 'Task Overview',
              subtitle: 'Daily summary notification',
              trailing: _Toggle(
                _s.taskOverview,
                (v) => _setDailySummary(v, _s.copyWith(taskOverview: v)),
              ),
            ),
            _Row(
              icon: Icons.wb_sunny_outlined,
              color: 'amber',
              title: 'Morning Plan',
              subtitle: 'Daily morning briefing',
              trailing: _Toggle(
                _s.morningPlan,
                (v) => _setDailySummary(v, _s.copyWith(morningPlan: v)),
              ),
            ),
            _Row(
              icon: Icons.nightlight_outlined,
              color: 'pink',
              title: 'Evening Review',
              subtitle: 'End-of-day recap',
              trailing: _Toggle(
                _s.eveningReview,
                (v) => _setDailySummary(v, _s.copyWith(eveningReview: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────────

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final cs = Theme.of(context).colorScheme;

    Widget option(
      String label,
      IconData icon,
      String color,
      bool selected,
      VoidCallback onTap,
    ) {
      return _Row(
        icon: icon,
        color: color,
        title: label,
        onTap: onTap,
        trailing:
            selected
                ? Icon(Icons.check, size: 18, color: context.appColors.accent)
                : null,
      );
    }

    return _SubScaffold(
      title: 'Theme',
      children: [
        const _SectionLabel('Appearance'),
        _Card(
          children: [
            option('Light', Icons.light_mode, 'amber', !isDark, () {
              if (isDark) themeProvider.toggleTheme();
            }),
            option('Dark', Icons.nightlight_outlined, 'indigo', isDark, () {
              if (!isDark) themeProvider.toggleTheme();
            }),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Accent Color'),
        _Card(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in kAccentChoices)
                  _AccentDot(
                    color: c,
                    selected: c == themeProvider.accent,
                    onTap: () => themeProvider.setAccent(c),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Used for buttons, highlights, toggles and charts.',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(120)),
          ),
        ),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Accent color',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? cs.onSurface : Colors.transparent,
              width: 3,
            ),
          ),
          child:
              selected
                  ? Icon(Icons.check, size: 18, color: onAccentFor(color))
                  : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  WIDGET
// ─────────────────────────────────────────────────────────────────

class WidgetPage extends StatefulWidget {
  final ToDoDataBase db;
  const WidgetPage({super.key, required this.db});

  @override
  State<WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<WidgetPage> {
  AppSettings get _s => widget.db.settings;
  //dynamic _get(String k, dynamic f) => _s[k] ?? f;
  void _set(AppSettings newSettings) {
    setState(() => widget.db.settings = newSettings);
    widget.db.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Widget',
      children: [
        const _SectionLabel('Widget Appearance'),
        _Card(
          children: [
            _Row(
              icon: Icons.dashboard_customize_outlined,
              color: 'teal',
              title: 'Widget Style',
              chevron: true,
              trailing: _ValueBadge(_s.widgetStyle),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Widget Style',
                  options: const ['Compact', 'Expanded', 'Minimal'],
                  current: _s.widgetStyle,
                );
                if (v != null) _set(_s.copyWith(widgetStyle: v));
              },
            ),
            _Row(
              icon: Icons.aspect_ratio,
              color: 'purple',
              title: 'Widget Size',
              chevron: true,
              trailing: _ValueBadge(_s.widgetSize),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Widget Size',
                  options: const ['Small', 'Medium', 'Large'],
                  current: _s.widgetSize,
                );
                if (v != null) _set(_s.copyWith(widgetSize: v));
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Widget Content'),
        _Card(
          children: [
            _Row(
              icon: Icons.check_box_outlined,
              color: 'green',
              title: 'Show Completed Tasks',
              trailing: _Toggle(
                _s.widgetShowCompleted,
                (v) => _set(_s.copyWith(widgetShowCompleted: v)),
              ),
            ),
            _Row(
              icon: Icons.star_outline,
              color: 'amber',
              title: 'Show Priority Tasks Only',
              trailing: _Toggle(
                _s.widgetPriorityOnly,
                (v) => _set(_s.copyWith(widgetPriorityOnly: v)),
              ),
            ),
            _Row(
              icon: Icons.format_list_numbered,
              color: 'blue',
              title: 'Number of Tasks',
              chevron: true,
              trailing: _ValueBadge('${_s.widgetTaskCount}'),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Tasks to Show',
                  options: const ['3', '4', '5', '6', '7', '8'],
                  current: '${_s.widgetTaskCount}',
                );
                if (v != null) _set(_s.copyWith(widgetTaskCount: int.parse(v)));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  DATE & TIME
// ─────────────────────────────────────────────────────────────────

class DateTimePage extends StatefulWidget {
  final ToDoDataBase db;
  const DateTimePage({super.key, required this.db});

  @override
  State<DateTimePage> createState() => _DateTimePageState();
}

class _DateTimePageState extends State<DateTimePage> {
  AppSettings get _s => widget.db.settings;
  //dynamic _get(String k, dynamic f) => _s[k] ?? f;
  void _set(AppSettings newSettings) {
    setState(() => widget.db.settings = newSettings);
    widget.db.saveSettings();
  }

  static const _timezones = [
    'UTC-12:00 (Baker Island)',
    'UTC-11:00 (Samoa)',
    'UTC-10:00 (Hawaii)',
    'UTC-8:00 (Pacific Time)',
    'UTC-7:00 (Mountain Time)',
    'UTC-6:00 (Central Time)',
    'UTC-5:00 (Eastern Time)',
    'UTC-4:00 (Atlantic Time)',
    'UTC-3:00 (Buenos Aires)',
    'UTC+0 (London / UTC)',
    'UTC+1:00 (Paris / Berlin)',
    'UTC+2:00 (Cairo)',
    'UTC+3:00 (Moscow)',
    'UTC+4:00 (Dubai)',
    'UTC+5:00 (Islamabad)',
    'UTC+5:30 (Colombo / Mumbai)',
    'UTC+6:00 (Dhaka)',
    'UTC+7:00 (Bangkok)',
    'UTC+8:00 (Singapore / Beijing)',
    'UTC+9:00 (Tokyo / Seoul)',
    'UTC+10:00 (Sydney)',
    'UTC+12:00 (Auckland)',
  ];

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Date & Time',
      children: [
        const _SectionLabel('Date & Time Preferences'),
        _Card(
          children: [
            _Row(
              icon: Icons.calendar_view_week,
              color: 'blue',
              title: 'First Day of Week',
              chevron: true,
              trailing: _ValueBadge(_s.firstDayOfWeek),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'First Day of Week',
                  options: const [
                    'Sunday',
                    'Monday',
                    'Saturday',
                    'System Default',
                  ],
                  current: _s.firstDayOfWeek,
                );
                if (v != null) _set(_s.copyWith(firstDayOfWeek: v));
              },
            ),
            _Row(
              icon: Icons.access_time,
              color: 'green',
              title: 'Time Format',
              chevron: true,
              trailing: _ValueBadge(_s.timeFormat),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Time Format',
                  options: const ['12 hour', '24 hour'],
                  current: _s.timeFormat,
                );
                if (v != null) _set(_s.copyWith(timeFormat: v));
              },
            ),
            _Row(
              icon: Icons.calendar_month,
              color: 'amber',
              title: 'Date Format',
              chevron: true,
              trailing: _ValueBadge(_s.dateFormat),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Date Format',
                  options: const ['d/m/y', 'm/d/y', 'y/m/d'],
                  current: _s.dateFormat,
                );
                if (v != null) _set(_s.copyWith(dateFormat: v));
              },
            ),
            _Row(
              icon: Icons.event_available,
              color: 'pink',
              title: 'Default Due Date',
              chevron: true,
              trailing: _ValueBadge(_s.defaultDueDate),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Default Due Date',
                  options: const ['Today', 'Tomorrow', 'No default'],
                  current: _s.defaultDueDate,
                );
                if (v != null) _set(_s.copyWith(defaultDueDate: v));
              },
            ),
            _Row(
              icon: Icons.public,
              color: 'teal',
              title: 'Time Zone',
              chevron: true,
              trailing: _ValueBadge(_s.timeZoneLabel),
              onTap: () async {
                final v = await _pickOption(
                  context,
                  title: 'Time Zone',
                  options: _timezones,
                  current: _s.timeZoneLabel,
                  searchable: true,
                );
                if (v != null) {
                  final location =
                      DateTimeUtilsHelper.locationFromTimeZoneLabel(v);
                  if (location != null) tz.setLocalLocation(location);
                  _set(
                    _s.copyWith(timeZoneLabel: v, timeZoneManuallySet: true),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ACCOUNT
// ─────────────────────────────────────────────────────────────────

class AccountPage extends StatelessWidget {
  final ToDoDataBase db;
  const AccountPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final name = auth.displayName.isNotEmpty ? auth.displayName : 'Guest User';
    final email =
        auth.isGoogleSignedIn
            ? (auth.email.isNotEmpty ? auth.email : 'Google Account')
            : 'Local account';

    return _SubScaffold(
      title: 'Account',
      children: [
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.appColors.accent,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'G',
                  style: TextStyle(
                    color: context.appColors.onAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withAlpha(150),
                ),
              ),
              const SizedBox(height: 8),
              if (auth.isGoogleSignedIn)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF30A46C),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Account synced',
                      style: TextStyle(fontSize: 12, color: Color(0xFF30A46C)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _Card(
          children: [
            _Row(
              icon: Icons.key,
              color: 'gray',
              title: 'Change Password',
              chevron: true,
              onTap: () => _snack(context, 'Change password coming soon'),
            ),
            _Row(
              icon: Icons.devices,
              color: 'purple',
              title: 'Manage Devices',
              chevron: true,
              onTap: () => _snack(context, 'Manage devices coming soon'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Card(
          children: [
            _Row(
              icon: Icons.logout,
              color: 'red',
              title: 'Sign Out',
              titleColor: const Color(0xFFE5484D),
              onTap: () {
                context.read<AuthProvider>().signOutGoogle();
                Navigator.pop(context);
              },
            ),
            _Row(
              icon: Icons.delete_outline,
              color: 'red',
              title: 'Reset App Data',
              titleColor: const Color(0xFFE5484D),
              onTap: () => _confirmReset(context, db),
            ),
          ],
        ),
      ],
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _confirmReset(BuildContext context, ToDoDataBase db) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset App Data?'),
            content: const Text(
              'This will permanently delete all tasks and calendar data. '
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await db.clearToDoList();
                  await db.clearAllCalTasks();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (_) => false,
                    );
                  }
                },
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ABOUT
// ─────────────────────────────────────────────────────────────────

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    void snack(String msg) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));

    return _SubScaffold(
      title: 'About',
      children: [
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: context.appColors.accent,
                ),
                child: Icon(
                  Icons.check_box_outlined,
                  color: context.appColors.onAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'TaskFlow',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 3.4.1 (Build 2025.05)',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _Card(
          children: [
            _Row(
              icon: Icons.help_outline,
              color: 'blue',
              title: 'FAQ',
              trailing: Icon(
                Icons.open_in_new,
                size: 16,
                color: cs.onSurface.withAlpha(110),
              ),
              onTap: () => snack('Opening FAQ…'),
            ),
            _Row(
              icon: Icons.chat_bubble_outline,
              color: 'green',
              title: 'Feedback',
              chevron: true,
              onTap: () => snack('Opening feedback form…'),
            ),
            _Row(
              icon: Icons.share,
              color: 'teal',
              title: 'Share App',
              chevron: true,
              onTap: () => snack('Share link copied!'),
            ),
            _Row(
              icon: Icons.favorite_border,
              color: 'pink',
              title: 'Follow Us',
              trailing: Icon(
                Icons.open_in_new,
                size: 16,
                color: cs.onSurface.withAlpha(110),
              ),
              onTap: () => snack('Opening social page…'),
            ),
            _Row(
              icon: Icons.verified_user_outlined,
              color: 'gray',
              title: 'Privacy Policy',
              trailing: Icon(
                Icons.open_in_new,
                size: 16,
                color: cs.onSurface.withAlpha(110),
              ),
              onTap: () => snack('Opening Privacy Policy…'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Made with ♥ by TaskFlow Team\n© 2025 TaskFlow Inc. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(110)),
        ),
      ],
    );
  }
}
