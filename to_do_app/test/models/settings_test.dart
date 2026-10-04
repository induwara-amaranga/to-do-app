import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/settings.dart';

void main() {
  group('AppSettings', () {
    test('toMap/fromMap round-trips every field', () {
      const original = AppSettings(
        completionTone: false,
        completionAnimation: false,
        calendarEventsCollapsed: true,
        defaultCategory: 'Work',
        language: 'French',
        reminderTime: '10',
        reminderType: 'Hours',
        notifRingtone: 'Bell',
        alarmRingtone: 'Siren',
        alarmName: 'My Alarm',
        notifName: 'My Notif',
        lockScreenReminder: false,
        quickAddNotif: false,
        taskOverview: true,
        morningPlan: true,
        eveningReview: true,
        widgetStyle: 'Detailed',
        widgetSize: 'Large',
        widgetShowCompleted: true,
        widgetPriorityOnly: false,
        widgetTaskCount: 9,
        firstDayOfWeek: 'Monday',
        timeFormat: '24 hour',
        dateFormat: 'm/d/y',
        defaultDueDate: 'Tomorrow',
        timeZoneLabel: 'Asia/Tokyo',
        timeZoneManuallySet: true,
        keepLatestPastTasks: 1000,
      );
      final copy = AppSettings.fromMap(original.toMap());
      expect(copy.toMap(), original.toMap());
    });

    test('fromMap accepts the untyped maps Hive returns', () {
      final Map<dynamic, dynamic> hiveLike = {'widgetTaskCount': 12};
      expect(AppSettings.fromMap(hiveLike).widgetTaskCount, 12);
    });

    test('fromMap on an empty map falls back to sane toggles', () {
      final s = AppSettings.fromMap({});
      expect(s.completionTone, isTrue);
      expect(s.completionAnimation, isTrue);
      expect(s.timeFormat, '12 hour');
      expect(s.dateFormat, 'd/m/y');
      expect(s.defaultDueDate, 'Today');
      expect(s.widgetTaskCount, 5);
      expect(s.timeZoneManuallySet, isFalse);
    });

    test('copyWith changes only the named fields', () {
      const base = AppSettings();
      final changed = base.copyWith(
        timeFormat: '24 hour',
        alarmName: 'Loud',
        notifName: 'Soft',
      );
      expect(changed.timeFormat, '24 hour');
      expect(changed.alarmName, 'Loud');
      expect(changed.notifName, 'Soft');
      expect(changed.dateFormat, base.dateFormat);
      expect(changed.completionTone, base.completionTone);
    });

    test('copyWith with no arguments is equivalent', () {
      const base = AppSettings(widgetTaskCount: 3);
      expect(base.copyWith().toMap(), base.toMap());
    });

    test('keepLatestPastTasks defaults to never and round-trips', () {
      expect(const AppSettings().keepLatestPastTasks, 0);
      expect(AppSettings.fromMap({}).keepLatestPastTasks, 0);
      final s = const AppSettings().copyWith(keepLatestPastTasks: 2000);
      expect(AppSettings.fromMap(s.toMap()).keepLatestPastTasks, 2000);
      expect(s.copyWith().keepLatestPastTasks, 2000);
    });

    test('reminderTypeNormalized lower-cases the UI value', () {
      expect(
        const AppSettings(reminderType: 'Minutes').reminderTypeNormalized,
        'minutes',
      );
      expect(
        const AppSettings(reminderType: 'None').reminderTypeNormalized,
        'none',
      );
    });
  });
}
