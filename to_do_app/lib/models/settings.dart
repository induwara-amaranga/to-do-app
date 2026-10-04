// settings_model.dart
class AppSettings {
  final bool completionTone;
  final bool completionAnimation;
  // Calendar-event lists on the Tasks and Calendar pages start collapsed
  // once the user has collapsed them (remembered across launches).
  final bool calendarEventsCollapsed;
  final String defaultCategory;
  final String language;
  final String reminderTime;
  final String reminderType;
  final String notifRingtone;
  final String alarmRingtone;
  final String alarmName;
  final String notifName;
  final bool lockScreenReminder;
  final bool quickAddNotif;
  final bool taskOverview;
  final bool morningPlan;
  final bool eveningReview;
  final String widgetStyle;
  final String widgetSize;
  final bool widgetShowCompleted;
  final bool widgetPriorityOnly;
  final int widgetTaskCount;
  final String firstDayOfWeek;
  final String timeFormat;
  final String dateFormat;
  final String defaultDueDate;
  final String timeZoneLabel;

  /// Accent colour as an ARGB int (default amber 0xFFFFB31A).
  final int accentColor;

  /// Appearance and list preferences, restored on launch.
  final bool darkMode;
  final String taskSortMode; // SortingMode.name
  final String taskGroupMode; // GroupingMode.name
  final String timetableView; // 'tileView' | 'listView'
  final String timetableSortMode; // SortingMode.name

  /// True once the user explicitly picks a time zone in Settings.
  /// Until then, [timeZoneLabel] is kept in sync with device auto-detection
  /// on every launch (see main.dart's initLocalTimeZone).
  final bool timeZoneManuallySet;

  /// [reminderType] is stored with UI casing ("Minutes", "None"); task
  /// creation/repeat services compare against the lowercase canonical
  /// values in [remainderTypes] (models/types.dart).
  String get reminderTypeNormalized => reminderType.toLowerCase();

  const AppSettings({
    this.completionTone = true,
    this.completionAnimation = true,
    this.calendarEventsCollapsed = false,
    this.defaultCategory = 'None',
    this.language = 'English',
    this.reminderTime = '0',
    this.reminderType = 'Minutes',
    this.notifRingtone = 'Chime',
    this.alarmRingtone = 'Radar',
    this.alarmName = 'Default Alarm',
    this.notifName = 'Default Notification',
    this.lockScreenReminder = true,
    this.quickAddNotif = true,
    this.taskOverview = false,
    this.morningPlan = false,
    this.eveningReview = false,
    this.widgetStyle = 'Compact',
    this.widgetSize = 'Medium',
    this.widgetShowCompleted = false,
    this.widgetPriorityOnly = true,
    this.widgetTaskCount = 5,
    this.firstDayOfWeek = 'Sunday',
    this.timeFormat = '12 hour',
    this.dateFormat = 'd/m/y',
    this.defaultDueDate = 'Today',
    this.timeZoneLabel = 'UTC+5:30',
    this.accentColor = 0xFFFFB31A,
    this.darkMode = false,
    this.taskSortMode = 'createdDateDecreasing',
    this.taskGroupMode = 'Default',
    this.timetableView = 'tileView',
    this.timetableSortMode = 'createdDateDecreasing',
    this.timeZoneManuallySet = false,
  });

  AppSettings copyWith({
    bool? completionTone,
    bool? completionAnimation,
    bool? calendarEventsCollapsed,
    String? defaultCategory,
    String? language,
    String? reminderTime,
    String? reminderType,
    String? notifRingtone,
    String? alarmRingtone,
    bool? lockScreenReminder,
    bool? quickAddNotif,
    bool? taskOverview,
    bool? morningPlan,
    bool? eveningReview,
    String? widgetStyle,
    String? widgetSize,
    bool? widgetShowCompleted,
    bool? widgetPriorityOnly,
    int? widgetTaskCount,
    String? firstDayOfWeek,
    String? timeFormat,
    String? dateFormat,
    String? defaultDueDate,
    String? timeZoneLabel,
    int? accentColor,
    bool? darkMode,
    String? taskSortMode,
    String? taskGroupMode,
    String? timetableView,
    String? timetableSortMode,
    bool? timeZoneManuallySet,
    String? alarmName,
    String? notifName,
  }) {
    return AppSettings(
      completionTone: completionTone ?? this.completionTone,
      completionAnimation: completionAnimation ?? this.completionAnimation,
      calendarEventsCollapsed:
          calendarEventsCollapsed ?? this.calendarEventsCollapsed,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      language: language ?? this.language,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderType: reminderType ?? this.reminderType,
      notifRingtone: notifRingtone ?? this.notifRingtone,
      alarmRingtone: alarmRingtone ?? this.alarmRingtone,
      alarmName: alarmName ?? this.alarmName,
      notifName: notifName ?? this.notifName,
      lockScreenReminder: lockScreenReminder ?? this.lockScreenReminder,
      quickAddNotif: quickAddNotif ?? this.quickAddNotif,
      taskOverview: taskOverview ?? this.taskOverview,
      morningPlan: morningPlan ?? this.morningPlan,
      eveningReview: eveningReview ?? this.eveningReview,
      widgetStyle: widgetStyle ?? this.widgetStyle,
      widgetSize: widgetSize ?? this.widgetSize,
      widgetShowCompleted: widgetShowCompleted ?? this.widgetShowCompleted,
      widgetPriorityOnly: widgetPriorityOnly ?? this.widgetPriorityOnly,
      widgetTaskCount: widgetTaskCount ?? this.widgetTaskCount,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      timeFormat: timeFormat ?? this.timeFormat,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultDueDate: defaultDueDate ?? this.defaultDueDate,
      timeZoneLabel: timeZoneLabel ?? this.timeZoneLabel,
      accentColor: accentColor ?? this.accentColor,
      darkMode: darkMode ?? this.darkMode,
      taskSortMode: taskSortMode ?? this.taskSortMode,
      taskGroupMode: taskGroupMode ?? this.taskGroupMode,
      timetableView: timetableView ?? this.timetableView,
      timetableSortMode: timetableSortMode ?? this.timetableSortMode,
      timeZoneManuallySet: timeZoneManuallySet ?? this.timeZoneManuallySet,
    );
  }

  // Hive stores this as a plain map — forward-compatible since
  // fromMap uses defaults for any missing keys (e.g. after an upgrade).
  Map<String, dynamic> toMap() => {
    'completionTone': completionTone,
    'completionAnimation': completionAnimation,
    'calendarEventsCollapsed': calendarEventsCollapsed,
    'defaultCategory': defaultCategory,
    'language': language,
    'reminderTime': reminderTime,
    'reminderType': reminderType,
    'notifRingtone': notifRingtone,
    'alarmRingtone': alarmRingtone,
    'alarmName': alarmName,
    'notifName': notifName,
    'lockScreenReminder': lockScreenReminder,
    'quickAddNotif': quickAddNotif,
    'taskOverview': taskOverview,
    'morningPlan': morningPlan,
    'eveningReview': eveningReview,
    'widgetStyle': widgetStyle,
    'widgetSize': widgetSize,
    'widgetShowCompleted': widgetShowCompleted,
    'widgetPriorityOnly': widgetPriorityOnly,
    'widgetTaskCount': widgetTaskCount,
    'firstDayOfWeek': firstDayOfWeek,
    'timeFormat': timeFormat,
    'dateFormat': dateFormat,
    'defaultDueDate': defaultDueDate,
    'timeZoneLabel': timeZoneLabel,
    'accentColor': accentColor,
    'darkMode': darkMode,
    'taskSortMode': taskSortMode,
    'taskGroupMode': taskGroupMode,
    'timetableView': timetableView,
    'timetableSortMode': timetableSortMode,
    'timeZoneManuallySet': timeZoneManuallySet,
  };

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) => AppSettings(
    completionTone: map['completionTone'] as bool? ?? true,
    completionAnimation: map['completionAnimation'] as bool? ?? true,
    calendarEventsCollapsed: map['calendarEventsCollapsed'] as bool? ?? false,
    defaultCategory: map['defaultCategory'] as String? ?? 'Inbox',
    language: map['language'] as String? ?? 'English',
    reminderTime: map['reminderTime'] as String? ?? '9:00 AM',
    reminderType: map['reminderType'] as String? ?? 'Notification',
    notifRingtone: map['notifRingtone'] as String? ?? 'Chime',
    alarmRingtone: map['alarmRingtone'] as String? ?? 'Radar',
    alarmName: map['alarmName'] as String? ?? 'Default Alarm',
    notifName: map['notifName'] as String? ?? 'Default Notification',
    lockScreenReminder: map['lockScreenReminder'] as bool? ?? true,
    quickAddNotif: map['quickAddNotif'] as bool? ?? true,
    taskOverview: map['taskOverview'] as bool? ?? false,
    morningPlan: map['morningPlan'] as bool? ?? true,
    eveningReview: map['eveningReview'] as bool? ?? false,
    widgetStyle: map['widgetStyle'] as String? ?? 'Compact',
    widgetSize: map['widgetSize'] as String? ?? 'Medium',
    widgetShowCompleted: map['widgetShowCompleted'] as bool? ?? false,
    widgetPriorityOnly: map['widgetPriorityOnly'] as bool? ?? true,
    widgetTaskCount: map['widgetTaskCount'] as int? ?? 5,
    firstDayOfWeek: map['firstDayOfWeek'] as String? ?? 'Sunday',
    timeFormat: map['timeFormat'] as String? ?? '12 hour',
    dateFormat: map['dateFormat'] as String? ?? 'd/m/y',
    defaultDueDate: map['defaultDueDate'] as String? ?? 'Today',
    timeZoneLabel: map['timeZoneLabel'] as String? ?? 'UTC+0',
    accentColor: map['accentColor'] as int? ?? 0xFFFFB31A,
    darkMode: map['darkMode'] as bool? ?? false,
    taskSortMode: map['taskSortMode'] as String? ?? 'createdDateDecreasing',
    taskGroupMode: map['taskGroupMode'] as String? ?? 'Default',
    timetableView: map['timetableView'] as String? ?? 'tileView',
    timetableSortMode:
        map['timetableSortMode'] as String? ?? 'createdDateDecreasing',
    timeZoneManuallySet: map['timeZoneManuallySet'] as bool? ?? false,
  );
}
