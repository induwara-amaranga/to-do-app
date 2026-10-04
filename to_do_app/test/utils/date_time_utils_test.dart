import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:to_do_app/utils/string_utils.dart';

import '../helpers/test_data.dart';

void main() {
  setUpAll(initTestTimeZone); // Asia/Colombo, UTC+5:30

  group('parse / format', () {
    test('parseDate reads yyyy-MM-dd', () {
      expect(DateTimeUtilsHelper.parseDate('2025-03-04'), DateTime(2025, 3, 4));
    });

    test('parseDate returns the 1970 sentinel for null, zeros and garbage', () {
      final epoch = DateTime(1970, 1, 1);
      expect(DateTimeUtilsHelper.parseDate(null), epoch);
      expect(DateTimeUtilsHelper.parseDate('0000-00-00'), epoch);
      expect(DateTimeUtilsHelper.parseDate('not a date'), epoch);
    });

    test('parseDate honours a custom format', () {
      expect(
        DateTimeUtilsHelper.parseDate('04/03/2025', format: 'dd/MM/yyyy'),
        DateTime(2025, 3, 4),
      );
    });

    test('formatDate and formatTime', () {
      expect(
        DateTimeUtilsHelper.formatDate(DateTime(2025, 3, 4)),
        '2025-03-04',
      );
      expect(
        DateTimeUtilsHelper.formatDate(DateTime(2025, 3, 4), format: 'yyyy-MM'),
        '2025-03',
      );
      expect(
        DateTimeUtilsHelper.formatTime(DateTime(2025, 1, 1, 7, 5)),
        '07:05',
      );
    });

    test('formatTime(null) is the "no time" marker 24:00', () {
      expect(DateTimeUtilsHelper.formatTime(null), '24:00');
    });

    test('formatDate(null) falls back to today', () {
      expect(
        DateTimeUtilsHelper.formatDate(null),
        DateTimeUtilsHelper.formatDate(DateTime.now()),
      );
    });

    test('parseTime reads HH:mm, 24:00 and rejects garbage', () {
      final t = DateTimeUtilsHelper.parseTime('13:45')!;
      expect([t.hour, t.minute], [13, 45]);
      final end = DateTimeUtilsHelper.parseTime('24:00')!;
      expect([end.hour, end.minute, end.second], [23, 59, 59]);
      expect(DateTimeUtilsHelper.parseTime('soon'), isNull);
    });

    test('parseDateTime / formatDateTime', () {
      final dt = DateTimeUtilsHelper.parseDateTime('2025-03-04 10:30:00.000Z');
      expect(dt.isUtc, isTrue);
      expect(dt.hour, 10);
      expect(DateTimeUtilsHelper.formatDateTime(dt), dt.toString());
    });

    test('repeated parses return equal results (cache is transparent)', () {
      final a = DateTimeUtilsHelper.parseDate('2031-12-25');
      final b = DateTimeUtilsHelper.parseDate('2031-12-25');
      expect(a, b);
    });
  });

  group('combine', () {
    test('combineDateAndTime merges date and time parts', () {
      final r = DateTimeUtilsHelper.combineDateAndTime(
        DateTime(2025, 3, 4),
        DateTime(1970, 1, 1, 9, 15),
      );
      expect(r, DateTime(2025, 3, 4, 9, 15));
    });

    test('combineDateAndTime defaults a missing time to 23:59', () {
      final r = DateTimeUtilsHelper.combineDateAndTime(
        DateTime(2025, 3, 4),
        null,
      );
      expect(r, DateTime(2025, 3, 4, 23, 59));
    });

    test('combineDateAndTimeFromStrings', () {
      expect(
        DateTimeUtilsHelper.combineDateAndTimeFromStrings(
          '2025-03-04',
          '06:30',
        ),
        DateTime(2025, 3, 4, 6, 30),
      );
      expect(
        DateTimeUtilsHelper.combineDateAndTimeFromStrings('2025-03-04', 'bad'),
        DateTime(2025, 3, 4, 23, 59),
      );
    });

    test('utcDatetimeFromStrings returns a UTC value', () {
      final r = DateTimeUtilsHelper.utcDatetimeFromStrings(
        '2025-03-04',
        '10:30',
      );
      expect(r, DateTime.utc(2025, 3, 4, 10, 30));
      expect(r.isUtc, isTrue);
    });

    test('utcDateTimeFromUTCvalues keeps the wall-clock values', () {
      final r = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(
        DateTime(2025, 3, 4, 10, 30, 5),
      );
      expect(r, DateTime.utc(2025, 3, 4, 10, 30, 5));
    });
  });

  group('time zone conversion (tz.local = Asia/Colombo)', () {
    test('toUtcUsingLocal subtracts the +5:30 offset', () {
      final r = DateTimeUtilsHelper.toUtcUsingLocal(
        DateTime(2025, 1, 1, 10, 0),
      );
      expect(r, DateTime.utc(2025, 1, 1, 4, 30));
    });

    test('toLocalUsingTz adds the +5:30 offset to UTC values', () {
      final r = DateTimeUtilsHelper.toLocalUsingTz(DateTime(2025, 1, 1, 10, 0));
      expect([r.year, r.month, r.day, r.hour, r.minute], [2025, 1, 1, 15, 30]);
    });

    test('toLocalUsingTz crosses midnight', () {
      final r = DateTimeUtilsHelper.toLocalUsingTz(DateTime(2025, 1, 1, 20, 0));
      expect([r.day, r.hour, r.minute], [2, 1, 30]);
    });

    test('local to UTC and back is the identity', () {
      final local = DateTime(2025, 6, 15, 14, 20);
      final utc = DateTimeUtilsHelper.toUtcUsingLocal(local);
      final back = DateTimeUtilsHelper.toLocalUsingTz(utc);
      expect(
        [back.year, back.month, back.day, back.hour, back.minute],
        [2025, 6, 15, 14, 20],
      );
    });

    test('locationFromTimeZoneLabel resolves friendly labels', () {
      expect(
        DateTimeUtilsHelper.locationFromTimeZoneLabel(
          'UTC+5:30 (Colombo / Mumbai)',
        )?.name,
        'Asia/Colombo',
      );
      expect(
        DateTimeUtilsHelper.locationFromTimeZoneLabel(
          'UTC-5:00 (Eastern Time)',
        )?.name,
        'America/New_York',
      );
    });

    test('locationFromTimeZoneLabel accepts raw IANA ids', () {
      expect(
        DateTimeUtilsHelper.locationFromTimeZoneLabel('Asia/Tokyo')?.name,
        'Asia/Tokyo',
      );
    });

    test('locationFromTimeZoneLabel returns null for unknown labels', () {
      expect(
        DateTimeUtilsHelper.locationFromTimeZoneLabel('Mars/Base'),
        isNull,
      );
      expect(DateTimeUtilsHelper.locationFromTimeZoneLabel(''), isNull);
    });

    test('friendly labels offered in Settings map to a location', () {
      const labels = [
        'UTC-11:00 (Samoa)',
        'UTC-10:00 (Hawaii)',
        'UTC-8:00 (Pacific Time)',
        'UTC-7:00 (Mountain Time)',
        'UTC-6:00 (Central Time)',
        'UTC-5:00 (Eastern Time)',
        'UTC-4:00 (Atlantic Time)',
        'UTC-3:00 (Buenos Aires)',
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
      for (final l in labels) {
        expect(
          DateTimeUtilsHelper.locationFromTimeZoneLabel(l),
          isA<tz.Location>(),
          reason: l,
        );
      }
    });
  });

  group('known issues', () {
    test(
      'UTC-12 and UTC+0 labels resolve to a location',
      () {
        // 'Etc/GMT+12' and 'Etc/UTC' are not in package:timezone's
        // latest.dart database, so picking either label in Settings falls
        // through to auto-detect instead of applying the chosen zone.
        for (final l in ['UTC-12:00 (Baker Island)', 'UTC+0 (London / UTC)']) {
          expect(
            DateTimeUtilsHelper.locationFromTimeZoneLabel(l),
            isA<tz.Location>(),
            reason: l,
          );
        }
      },
      skip: 'Known bug: Etc/GMT+12 and Etc/UTC missing from tz database',
    );
  });

  group('display formatting follows AppSettings', () {
    final date = DateTime(2026, 1, 5, 9, 5);
    const dmy = AppSettings(dateFormat: 'd/m/y');
    const mdy = AppSettings(dateFormat: 'm/d/y');
    const ymd = AppSettings(dateFormat: 'y/m/d');

    test('displayDateNumeric', () {
      expect(DateTimeUtilsHelper.displayDateNumeric(date, dmy), '5/1/2026');
      expect(DateTimeUtilsHelper.displayDateNumeric(date, mdy), '1/5/2026');
      expect(DateTimeUtilsHelper.displayDateNumeric(date, ymd), '2026/1/5');
      expect(DateTimeUtilsHelper.displayDateNumeric(null, dmy), '');
    });

    test('displayDateFriendly', () {
      expect(DateTimeUtilsHelper.displayDateFriendly(date, dmy), '5 Jan, 2026');
      expect(DateTimeUtilsHelper.displayDateFriendly(date, mdy), 'Jan 5, 2026');
      expect(DateTimeUtilsHelper.displayDateFriendly(date, ymd), '2026 Jan 5');
      expect(DateTimeUtilsHelper.displayDateFriendly(null, dmy), '');
    });

    test('displayDayMonth', () {
      expect(DateTimeUtilsHelper.displayDayMonth(date, dmy), '5 Jan');
      expect(DateTimeUtilsHelper.displayDayMonth(date, mdy), 'Jan 5');
    });

    test('displayMonthYear', () {
      expect(DateTimeUtilsHelper.displayMonthYear(date, dmy), 'January 2026');
      expect(DateTimeUtilsHelper.displayMonthYear(date, ymd), '2026 January');
    });

    test('displayTime honours 12/24 hour', () {
      expect(
        DateTimeUtilsHelper.displayTime(
          date,
          const AppSettings(timeFormat: '12 hour'),
        ),
        '9:05 AM',
      );
      expect(
        DateTimeUtilsHelper.displayTime(
          date,
          const AppSettings(timeFormat: '24 hour'),
        ),
        '09:05',
      );
      expect(DateTimeUtilsHelper.displayTime(null, const AppSettings()), '');
    });

    test('display helpers never change the storage format', () {
      expect(DateTimeUtilsHelper.formatDate(date), '2026-01-05');
      expect(DateTimeUtilsHelper.formatTime(date), '09:05');
    });
  });

  group('settings mappers', () {
    test('initialDueDateFromSetting', () {
      final today = DateTime.now();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final a = DateTimeUtilsHelper.initialDueDateFromSetting('Today')!;
      final b = DateTimeUtilsHelper.initialDueDateFromSetting('Tomorrow')!;
      expect([a.year, a.month, a.day], [today.year, today.month, today.day]);
      expect(
        [b.year, b.month, b.day],
        [tomorrow.year, tomorrow.month, tomorrow.day],
      );
      expect(
        DateTimeUtilsHelper.initialDueDateFromSetting('No default'),
        isNull,
      );
      expect(DateTimeUtilsHelper.initialDueDateFromSetting('???'), isNull);
    });

    test('startingDayOfWeekFromSetting', () {
      expect(
        DateTimeUtilsHelper.startingDayOfWeekFromSetting('Sunday'),
        StartingDayOfWeek.sunday,
      );
      expect(
        DateTimeUtilsHelper.startingDayOfWeekFromSetting('Saturday'),
        StartingDayOfWeek.saturday,
      );
      expect(
        DateTimeUtilsHelper.startingDayOfWeekFromSetting('Monday'),
        StartingDayOfWeek.monday,
      );
      expect(
        DateTimeUtilsHelper.startingDayOfWeekFromSetting('System Default'),
        StartingDayOfWeek.monday,
      );
    });
  });

  group('StringUtils.listFromString', () {
    test('parses a bracketed, comma separated string', () {
      expect(StringUtils.listFromString('[apple, banana, orange]'), [
        'apple',
        'banana',
        'orange',
      ]);
    });

    test('single element', () {
      expect(StringUtils.listFromString('[one]'), ['one']);
    });
  });
}
