import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/models/settings.dart';

class DateTimeUtilsHelper {
  // ── Caches ──────────────────────────────────────────────────────────────
  // Building a DateFormat compiles its pattern, and these helpers are called
  // per task inside sort comparators, grouping and every tile build — so with
  // a large list the same handful of patterns was being recompiled thousands
  // of times per frame. Formatters are reused per pattern, and parse results
  // (DateTime is immutable, so sharing is safe) are memoised per input
  // string: stored due dates/times repeat heavily across tasks.
  static final Map<String, DateFormat> _formatters = {};
  static DateFormat _fmt(String pattern) =>
      _formatters.putIfAbsent(pattern, () => DateFormat(pattern));

  static const int _maxParseCacheSize = 4096;
  static final Map<String, DateTime> _parsedDates = {};
  static final Map<String, DateTime?> _parsedTimes = {};

  static void _boundCache(Map<String, Object?> cache) {
    if (cache.length >= _maxParseCacheSize) cache.clear();
  }

  // Parse String → DateTime
  static DateTime? parseDate(String? dateStr, {String format = "yyyy-MM-dd"}) {
    if (dateStr == null || dateStr == "0000-00-00") {
      return DateTime(1970, 01, 01);
    }
    final key = '$format|$dateStr';
    final cached = _parsedDates[key];
    if (cached != null) return cached;
    DateTime taskDate;
    try {
      taskDate = _fmt(format).parse(dateStr);
    } catch (e) {
      taskDate = DateTime(1970, 01, 01);
    }
    _boundCache(_parsedDates);
    return _parsedDates[key] = taskDate;
  }

  // Format DateTime → String
  static String formatDate(DateTime? date, {String format = "yyyy-MM-dd"}) {
    String formatedDate =
        date != null
            ? _fmt(format).format(date)
            : _fmt(format).format(DateTime.now());

    return formatedDate;
  }

  static DateTime? parseTime(String timeStr, {String format = "HH:mm"}) {
    if (timeStr == "24:00") return DateTime(1970, 1, 1, 23, 59, 59);
    final key = '$format|$timeStr';
    if (_parsedTimes.containsKey(key)) return _parsedTimes[key];
    DateTime? taskTime;
    try {
      taskTime = _fmt(format).parse(timeStr);
    } catch (e) {
      taskTime = null; // null if parsing fails
    }
    _boundCache(_parsedTimes);
    return _parsedTimes[key] = taskTime;
  }

  static String formatTime(DateTime? time, {String format = "HH:mm"}) {
    if (time == null) return "24:00";
    return _fmt(format).format(time);
  }

  static DateTime parseDateTime(String timestamp) {
    DateTime dt = DateTime.parse(timestamp);
    return dt;
  }

  static String formatDateTime(DateTime? dt) {
    String timestamp = dt!.toString();
    return timestamp;
  }

  static DateTime combineDateAndTime(DateTime? date, DateTime? time) {
    if (date == null) date = DateTime.now();
    if (time == null) time = DateTime(1970, 1, 1, 23, 59);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static DateTime combineDateAndTimeFromStrings(
    String dateStr,
    String timeStr,
  ) {
    DateTime date = parseDate(dateStr) ?? DateTime.now();
    DateTime time = parseTime(timeStr) ?? DateTime(1970, 1, 1, 23, 59);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Converts a  DateTime with local values (assumed in tz.local) to UTC
  static DateTime toUtcUsingLocal(DateTime dateTime) {
    // Wrap the DateTime in tz.TZDateTime using tz.local
    //from tz of dateTime to utc
    final localTzDateTime = tz.TZDateTime.from(dateTime, tz.local);

    // Convert to UTC
    return localTzDateTime.toUtc();
  }

  /// Converts a DateTime with UTC values (or any DateTime) to tz.local time
  static DateTime toLocalUsingTz(DateTime dateTime) {
    final utcTime = DateTime.utc(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
    return tz.TZDateTime.from(utcTime, tz.local);
  }

  static DateTime utcDateTimeFromUTCvalues(DateTime dateTime) {
    return DateTime.utc(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
  }

  static DateTime utcDatetimeFromStrings(String dateStr, String timeStr) {
    DateTime date = parseDate(dateStr) ?? DateTime.now();
    DateTime time = parseTime(timeStr) ?? DateTime(1970, 1, 1, 23, 59);
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
  }

  /// Maps the "Default Due Date" setting ("Today" | "Tomorrow" | "No default")
  /// to an initial due date for the create-task sheet.
  static DateTime? initialDueDateFromSetting(String setting) {
    switch (setting) {
      case 'Today':
        return DateTime.now();
      case 'Tomorrow':
        return DateTime.now().add(const Duration(days: 1));
      default:
        return null;
    }
  }

  // ── User-facing display formatting (respects Settings; never used for
  // storage — storage always uses the fixed "yyyy-MM-dd"/"HH:mm" formats
  // above) ─────────────────────────────────────────────────────────────

  static String _numericDatePattern(String dateFormat) {
    switch (dateFormat) {
      case 'm/d/y':
        return 'M/d/y';
      case 'y/m/d':
        return 'y/M/d';
      case 'd/m/y':
      default:
        return 'd/M/y';
    }
  }

  static String _friendlyDatePattern(String dateFormat) {
    switch (dateFormat) {
      case 'm/d/y':
        return 'MMM d, yyyy';
      case 'y/m/d':
        return 'yyyy MMM d';
      case 'd/m/y':
      default:
        return 'd MMM, yyyy';
    }
  }

  /// Numeric day/month/year order per [AppSettings.dateFormat], e.g. "5/1/2026".
  static String displayDateNumeric(DateTime? date, AppSettings settings) {
    if (date == null) return '';
    return _fmt(_numericDatePattern(settings.dateFormat)).format(date);
  }

  /// Named-month date honoring the day/month order of [AppSettings.dateFormat],
  /// e.g. "5 Jan, 2026" (d/m/y) vs "Jan 5, 2026" (m/d/y).
  static String displayDateFriendly(DateTime? date, AppSettings settings) {
    if (date == null) return '';
    return _fmt(_friendlyDatePattern(settings.dateFormat)).format(date);
  }

  /// Compact "MMM d" / "d MMM" (no year) for chips and other tight spaces.
  static String displayDayMonth(DateTime date, AppSettings settings) {
    final pattern = settings.dateFormat == 'm/d/y' ? 'MMM d' : 'd MMM';
    return _fmt(pattern).format(date);
  }

  static String displayMonthYear(DateTime date, AppSettings settings) {
    final pattern = settings.dateFormat == 'y/m/d' ? 'yyyy MMMM' : 'MMMM yyyy';
    return _fmt(pattern).format(date);
  }

  /// 12-hour ("h:mm a") or 24-hour ("HH:mm") per [AppSettings.timeFormat].
  static String displayTime(DateTime? time, AppSettings settings) {
    if (time == null) return '';
    final pattern = settings.timeFormat == '24 hour' ? 'HH:mm' : 'h:mm a';
    return _fmt(pattern).format(time);
  }

  /// Maps the friendly labels shown in the Time Zone picker (Settings ›
  /// Date & Time) to a representative IANA zone id `tz.getLocation` accepts.
  static const Map<String, String> _timeZoneLabelToIana = {
    'UTC-12:00 (Baker Island)': 'Etc/GMT+12',
    'UTC-11:00 (Samoa)': 'Pacific/Pago_Pago',
    'UTC-10:00 (Hawaii)': 'Pacific/Honolulu',
    'UTC-8:00 (Pacific Time)': 'America/Los_Angeles',
    'UTC-7:00 (Mountain Time)': 'America/Denver',
    'UTC-6:00 (Central Time)': 'America/Chicago',
    'UTC-5:00 (Eastern Time)': 'America/New_York',
    'UTC-4:00 (Atlantic Time)': 'America/Halifax',
    'UTC-3:00 (Buenos Aires)': 'America/Argentina/Buenos_Aires',
    'UTC+0 (London / UTC)': 'Etc/UTC',
    'UTC+1:00 (Paris / Berlin)': 'Europe/Paris',
    'UTC+2:00 (Cairo)': 'Africa/Cairo',
    'UTC+3:00 (Moscow)': 'Europe/Moscow',
    'UTC+4:00 (Dubai)': 'Asia/Dubai',
    'UTC+5:00 (Islamabad)': 'Asia/Karachi',
    'UTC+5:30 (Colombo / Mumbai)': 'Asia/Colombo',
    'UTC+6:00 (Dhaka)': 'Asia/Dhaka',
    'UTC+7:00 (Bangkok)': 'Asia/Bangkok',
    'UTC+8:00 (Singapore / Beijing)': 'Asia/Singapore',
    'UTC+9:00 (Tokyo / Seoul)': 'Asia/Tokyo',
    'UTC+10:00 (Sydney)': 'Australia/Sydney',
    'UTC+12:00 (Auckland)': 'Pacific/Auckland',
  };

  /// Resolves a manually-picked Settings timezone label (or a raw IANA id,
  /// for values already written by auto-detection) to a [tz.Location].
  /// Returns null if unrecognized so callers can fall back to auto-detect.
  static tz.Location? locationFromTimeZoneLabel(String label) {
    final iana = _timeZoneLabelToIana[label] ?? label;
    try {
      return tz.getLocation(iana);
    } catch (_) {
      return null;
    }
  }

  /// Maps the "First Day of Week" setting to table_calendar's enum.
  /// "System Default" falls back to Monday (ISO-8601 week start).
  static StartingDayOfWeek startingDayOfWeekFromSetting(String setting) {
    switch (setting) {
      case 'Sunday':
        return StartingDayOfWeek.sunday;
      case 'Saturday':
        return StartingDayOfWeek.saturday;
      default:
        return StartingDayOfWeek.monday;
    }
  }
}
