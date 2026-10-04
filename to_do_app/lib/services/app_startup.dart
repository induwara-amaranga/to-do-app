import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

/// Start-up work that must not block the first frame.
///
/// `main()` only loads local data, applies the saved time zone and calls
/// `runApp`. Everything slow or network-bound (Supabase, Google / Outlook
/// silent sign-in, notifications, time-zone detection) runs afterwards, and
/// code that needs the result awaits [ready].
class AppStartup {
  /// Completes when the background initialisation started by `main()` has
  /// finished (successfully or not). Already complete until `main()` sets it,
  /// so pages work unchanged in tests and when opened without `main()`. The
  /// default is created on each read (not cached) so it always belongs to the
  /// caller's zone.
  static Future<void>? _ready;

  static Future<void> get ready => _ready ?? Future.value();
  static set ready(Future<void> value) => _ready = value;

  /// Back to "already complete" (tests).
  @visibleForTesting
  static void reset() => _ready = null;

  /// Runs [step] and swallows any error, so one failing service (offline,
  /// plugin missing) cannot stop the others or the app.
  static Future<void> guard(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {}
  }

  /// Sets `tz.local` from the saved settings, synchronously. A manually
  /// picked zone wins; otherwise the zone detected on the previous launch
  /// (stored as an IANA id) is used, so the first frame already shows the
  /// right times. Falls back to UTC until detection runs.
  static void applySavedTimeZone(ToDoDataBase db) {
    final saved = DateTimeUtilsHelper.locationFromTimeZoneLabel(
      db.settings.timeZoneLabel,
    );
    tz.setLocalLocation(saved ?? tz.getLocation('UTC'));
  }

  /// Detects the device time zone and, unless the user picked one manually,
  /// applies and saves it. Returns true if `tz.local` changed, so the caller
  /// can refresh anything already on screen. [detect] is injectable for tests.
  static Future<bool> detectTimeZone(
    ToDoDataBase db, {
    Future<String> Function()? detect,
  }) async {
    if (db.settings.timeZoneManuallySet &&
        DateTimeUtilsHelper.locationFromTimeZoneLabel(
              db.settings.timeZoneLabel,
            ) !=
            null) {
      return false; // already applied by applySavedTimeZone
    }
    final before = tz.local.name;
    try {
      final name =
          await (detect ??
              () async =>
                  (await FlutterTimezone.getLocalTimezone()).identifier)();
      tz.setLocalLocation(tz.getLocation(name));
      if (db.settings.timeZoneLabel != name) {
        db.settings = db.settings.copyWith(timeZoneLabel: name);
        db.saveSettings();
      }
    } catch (_) {
      // Keep whatever zone is already applied.
    }
    return tz.local.name != before;
  }
}
