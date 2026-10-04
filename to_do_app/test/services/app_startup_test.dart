import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/services/app_startup.dart';

import '../helpers/test_data.dart';

class _MemoryDb extends ToDoDataBase {
  int settingsSaves = 0;
  @override
  void saveSettings() => settingsSaves++;
}

_MemoryDb dbWith(AppSettings s) => _MemoryDb()..settings = s;

void main() {
  setUpAll(initTestTimeZone);

  group('AppStartup.ready', () {
    tearDown(() => AppStartup.ready = Future.value());

    test(
      'is already complete by default, so pages work without main()',
      () async {
        AppStartup.ready = Future.value();
        await AppStartup.ready.timeout(const Duration(milliseconds: 50));
      },
    );

    test('can be replaced by the real background start-up future', () async {
      var done = false;
      AppStartup.ready = Future.delayed(
        const Duration(milliseconds: 20),
      ).then((_) => done = true);
      expect(done, isFalse);
      await AppStartup.ready;
      expect(done, isTrue);
    });
  });

  group('AppStartup.guard', () {
    test('runs the step', () async {
      var ran = false;
      await AppStartup.guard(() async => ran = true);
      expect(ran, isTrue);
    });

    test('swallows a thrown error so other steps can continue', () async {
      await AppStartup.guard(() async => throw Exception('offline'));
      await AppStartup.guard(() => throw StateError('sync throw'));
    });

    test(
      'one failing step does not stop the others in a Future.wait',
      () async {
        final ran = <String>[];
        await Future.wait([
          AppStartup.guard(() async => throw Exception('supabase down')),
          AppStartup.guard(() async => ran.add('google')),
          AppStartup.guard(() async => ran.add('outlook')),
        ]);
        expect(ran, ['google', 'outlook']);
      },
    );
  });

  group('applySavedTimeZone', () {
    test('uses the zone detected on the previous launch', () {
      AppStartup.applySavedTimeZone(
        dbWith(const AppSettings(timeZoneLabel: 'Asia/Tokyo')),
      );
      expect(tz.local.name, 'Asia/Tokyo');
    });

    test('uses a manually chosen friendly label', () {
      AppStartup.applySavedTimeZone(
        dbWith(
          const AppSettings(
            timeZoneLabel: 'UTC-5:00 (Eastern Time)',
            timeZoneManuallySet: true,
          ),
        ),
      );
      expect(tz.local.name, 'America/New_York');
    });

    test('falls back to UTC for an unknown label (e.g. first launch)', () {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      AppStartup.applySavedTimeZone(
        dbWith(const AppSettings(timeZoneLabel: 'UTC+5:30')),
      );
      expect(tz.local.name, 'UTC');
    });

    test('is synchronous (no await needed before runApp)', () {
      tz.setLocalLocation(tz.getLocation('UTC'));
      AppStartup.applySavedTimeZone(
        dbWith(const AppSettings(timeZoneLabel: 'Europe/Paris')),
      );
      expect(tz.local.name, 'Europe/Paris');
    });
  });

  group('detectTimeZone', () {
    test(
      'applies and saves a newly detected zone, reporting the change',
      () async {
        tz.setLocalLocation(tz.getLocation('UTC'));
        final db = dbWith(const AppSettings(timeZoneLabel: 'UTC+5:30'));
        final changed = await AppStartup.detectTimeZone(
          db,
          detect: () async => 'Asia/Colombo',
        );
        expect(changed, isTrue);
        expect(tz.local.name, 'Asia/Colombo');
        expect(db.settings.timeZoneLabel, 'Asia/Colombo');
        expect(db.settingsSaves, 1);
      },
    );

    test('reports no change when the saved zone was already right', () async {
      final db = dbWith(const AppSettings(timeZoneLabel: 'Asia/Colombo'));
      AppStartup.applySavedTimeZone(db);
      final changed = await AppStartup.detectTimeZone(
        db,
        detect: () async => 'Asia/Colombo',
      );
      expect(changed, isFalse);
      expect(db.settingsSaves, 0, reason: 'nothing to write');
    });

    test('a manually chosen zone is never overridden', () async {
      final db = dbWith(
        const AppSettings(
          timeZoneLabel: 'UTC+9:00 (Tokyo / Seoul)',
          timeZoneManuallySet: true,
        ),
      );
      AppStartup.applySavedTimeZone(db);
      var asked = false;
      final changed = await AppStartup.detectTimeZone(
        db,
        detect: () async {
          asked = true;
          return 'Asia/Colombo';
        },
      );
      expect(changed, isFalse);
      expect(asked, isFalse, reason: 'no platform call needed');
      expect(tz.local.name, 'Asia/Tokyo');
    });

    test(
      'a manual zone with an unrecognised label falls back to detection',
      () async {
        tz.setLocalLocation(tz.getLocation('UTC'));
        final db = dbWith(
          const AppSettings(
            timeZoneLabel: 'garbage',
            timeZoneManuallySet: true,
          ),
        );
        final changed = await AppStartup.detectTimeZone(
          db,
          detect: () async => 'Europe/Paris',
        );
        expect(changed, isTrue);
        expect(tz.local.name, 'Europe/Paris');
      },
    );

    test('keeps the current zone if detection fails', () async {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      final db = dbWith(const AppSettings(timeZoneLabel: 'Asia/Tokyo'));
      final changed = await AppStartup.detectTimeZone(
        db,
        detect: () async => throw Exception('no platform'),
      );
      expect(changed, isFalse);
      expect(tz.local.name, 'Asia/Tokyo');
    });

    test('keeps the current zone if the detected name is unknown', () async {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      final db = dbWith(const AppSettings(timeZoneLabel: 'Asia/Tokyo'));
      final changed = await AppStartup.detectTimeZone(
        db,
        detect: () async => 'Mars/Olympus',
      );
      expect(changed, isFalse);
      expect(tz.local.name, 'Asia/Tokyo');
    });
  });
}
