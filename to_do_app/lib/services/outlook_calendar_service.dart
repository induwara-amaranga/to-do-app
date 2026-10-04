//import 'package:msal_flutter/msal_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:msal_auth/msal_auth.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/outlook_sign.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'dart:convert';

import 'package:uuid/uuid.dart';

final _uuid = Uuid();

class OutlookCalendarService {
  // A getter, not a `static final`: a final would freeze whatever the auth
  // service held when this class was first touched (null before sign-in).
  static String? get _accessToken => OutlookAuthService.accessToken;
  // static Future<bool> initialize() async {
  //   // _pca = await PublicClientApplication.createPublicClientApplication(
  //   //   _clientId,
  //   //   authority:
  //   //       "https://login.microsoftonline.com/common", // use your tenant if needed
  //   // );
  //   try {
  //     //   final result = await _pca.acquireToken(_scopes);
  //     //   _accessToken = result;

  //     // final msalAuth = await SingleAccountPca.create(
  //     //   clientId: _clientId,
  //     //   androidConfig: AndroidConfig(
  //     //     configFilePath: 'assets/msal_config.json',
  //     //     redirectUri: _redirectUri,
  //     //   ),
  //     //   appleConfig: AppleConfig(
  //     //     authority: '<Optional, but must be provided for b2c>',
  //     //     // Change authority type to 'b2c' for business to customer flow.
  //     //     authorityType: AuthorityType.aad,
  //     //     // Change broker if you need. Applicable only for iOS platform.
  //     //     broker: Broker.msAuthenticator,
  //     //   ),
  //     // );
  //     await init();
  //     _accessToken = await signIn();
  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  //   //return true;
  // }

  /// 🔹 Create or get a calendar named "ToDoList"
  static Future<Map<String, dynamic>?> createOrGetCalendar(
    List<Map<String, dynamic>> calendars,
  ) async {
    if (_accessToken == null) throw Exception('Not signed in');

    // 1️⃣ Fetch all calendars
    //final calendars = await getAllCalendars();

    // 2️⃣ Check if "ToDoList" calendar already exists
    final existing = calendars.firstWhere(
      (c) => (c['name'] as String?)?.toLowerCase() == 'todolist',
      orElse: () => {},
    );

    if (existing.isNotEmpty) {
      return existing;
    }

    // 3️⃣ Create a new calendar
    final url = Uri.parse("https://graph.microsoft.com/v1.0/me/calendars");
    final body = jsonEncode({
      "name": "ToDoList",
      "color": "auto", // optional, can choose any color
    });

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $_accessToken",
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (response.statusCode == 201) {
      final newCalendar = jsonDecode(response.body);
      calendars.add(newCalendar);
      return newCalendar;
    } else {
      return null;
    }
  }

  /// 🔹 Get all Outlook calendars for the signed-in user
  static Future<List<Map<String, dynamic>>> getAllCalendars() async {
    if (_accessToken == null) throw Exception('Not signed in');

    final url = Uri.parse("https://graph.microsoft.com/v1.0/me/calendars");
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List calendars = data['value'];

      return calendars.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  /// 🔹 Get events from a specific calendar
  static Future<List<Map<String, dynamic>>> getCalendarEvents(
    String calendarId,
  ) async {
    if (_accessToken == null) throw Exception('Not signed in');

    final url = Uri.parse(
      "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events",
    );
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['value']);
    } else {
      return [];
    }
  }

  /// 🔹 Delete an event from a specific calendar
  static Future<bool> deleteEvent(String calendarId, String eventId) async {
    if (_accessToken == null) throw Exception('Not signed in');

    final url = Uri.parse(
      "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events/$eventId",
    );

    final response = await http.delete(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode == 204) {
      return true;
    } else {
      return false;
    }
  }

  /// 🔹 Add a new event or update an existing one in a calendar
  static Future<void> addOrUpdateEvent(
    String calendarId,
    Task eventData,
  ) async {
    if (_accessToken == null) throw Exception('Not signed in');

    final String? eventId = eventData.remoteEventIds[2];

    // If event ID is provided → check if it exists
    bool exists = false;
    if (eventId != null) {
      final checkUrl = Uri.parse(
        "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events/$eventId",
      );

      final checkResponse = await http.get(
        checkUrl,
        headers: {"Authorization": "Bearer $_accessToken"},
      );

      if (checkResponse.statusCode == 200) {
        final data = jsonDecode(checkResponse.body);
        // Verify that the event actually belongs to your target calendar
        if (data['id'] == eventId /* && data['calendarId'] == calendarId*/ ) {
          exists = true;
        }
      }
    }
    String start = "";
    String end = "";
    try {
      start =
          DateTimeUtilsHelper.combineDateAndTimeFromStrings(
            eventData.dueDate!,
            eventData.dueTime!,
          ).toIso8601String();
      end =
          DateTimeUtilsHelper.combineDateAndTimeFromStrings(
            eventData.dueDate!,
            eventData.dueTime!,
          ).add(Duration(hours: 1)).toIso8601String();
    } catch (_) {}
    // 1️⃣ Build event JSON body (example mapping)
    final Map<String, dynamic> eventBody = {
      "subject": eventData.name,
      "body": {"contentType": "HTML", "content": "Weekly status update"},
      "start": {"dateTime": start, "timeZone": "UTC"},
      "end": {"dateTime": end, "timeZone": "UTC"},
    };
    final recurrence = _buildRecurrenceRule(eventData.repeatType);
    if (recurrence != null) {
      eventBody["recurrence"] = recurrence;
    }

    if (exists) {
      // 🔄 Update existing event
      final updateUrl = Uri.parse(
        "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events/$eventId",
      );

      final response = await http.patch(
        updateUrl,
        headers: {
          "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(eventBody),
      );

      if (response.statusCode == 200) {
        eventData.remoteEventIds[2] = jsonDecode(response.body)['id'];
      } else {}
    } else {
      //Print();
      // ➕ Create new event
      final createUrl = Uri.parse(
        "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events",
      );

      final response = await http.post(
        createUrl,
        headers: {
          "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(eventBody),
      );

      if (response.statusCode == 201) {
        eventData.remoteEventIds[2] = jsonDecode(response.body)['id'];
      } else {}
    }
  }

  /// 🔹 Import Outlook calendar events into local ToDo database
  static Future<void> importEventsToDB(
    String calendarId,
    ToDoDataBase db,
  ) async {
    if (_accessToken == null) throw Exception('Not signed in');

    // Microsoft Graph endpoint
    final url = Uri.parse(
      "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events?\$select=id,subject,bodyPreview,start,end,recurrence,type,seriesMasterId",
    );

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode != 200) {
      return;
    }

    final data = jsonDecode(response.body);
    final events = List<Map<String, dynamic>>.from(data['value']);

    // Pre-fetch recurrence for occurrence instances (recurrence is only on the master)
    final Map<String, String> masterRepeatTypeCache = {};
    for (final e in events) {
      final masterId = e['seriesMasterId'] as String?;
      if (masterId != null && !masterRepeatTypeCache.containsKey(masterId)) {
        masterRepeatTypeCache[masterId] = await _fetchMasterRepeatType(
          masterId,
        );
      }
    }

    for (final e in events) {
      if (e['start'] == null) continue;

      final startRaw = e['start']['dateTime'];
      if (startRaw == null) continue;

      // Convert start time to DateTime
      final start = DateTime.parse(startRaw).toLocal();
      final dueDate = DateTimeUtilsHelper.formatDate(start);
      final dueTime = DateTimeUtilsHelper.formatTime(start);

      final eventId = e['id'] ?? _uuid.v4();

      // Check if already exists in DB
      final existingIndex = db.toDoList.indexWhere(
        (t) =>
            t.remoteEventIds[2] == eventId && t.localCalendarId == calendarId,
      );

      final repeatType =
          e['recurrence'] != null
              ? _repeatTypeFromRecurrence(
                e['recurrence'] as Map<String, dynamic>?,
              )
              : masterRepeatTypeCache[e['seriesMasterId']] ?? 'none';

      if (existingIndex != -1) {
        // ✏️ Update existing record
        final t = db.toDoList[existingIndex];
        t.name = e['subject'] ?? 'Untitled Event';
        t.note = e['bodyPreview'] ?? '';
        t.dueDate = dueDate;
        t.dueTime = dueTime;
        t.category = 'None';
        t.priority = 'Low';
        t.repeatType = repeatType;
        t.reminderAmount = 10;
        t.reminderType = 'none';
        t.isStarred = false;
        t.subtasks = [];
        continue;
      }

      // ➕ Add new record
      db.toDoList.add(
        Task(
          name: e['subject'] ?? 'Untitled Event',
          completed: false,
          note: e['bodyPreview'] ?? '',
          dueDate: dueDate,
          dueTime: dueTime,
          category: 'None',
          priority: 'Low',
          repeatType: repeatType,
          reminderAmount: 10,
          reminderType: 'none',
          isStarred: false,
          createdAt: DateTime.now().toUtc().toString(),
          id: _uuid.v4(),
          subtasks: [],
          localCalendarId: calendarId,
          localEventId: eventId,
          remoteEventIds: ["", "", eventId],
          source: "outlook",
          completedAt: "none",
          notificationIds: [],
        ),
      );
    }

    await db.saveToDoList();
  }

  /// (Optional) Setter for access token from login
  static void setAccessToken(String token) {
    OutlookAuthService.accessToken = token;
  }

  /// 🔹 Import view-only Outlook events (no editing)
  ///
  /// With [replace], the cached Outlook events are swapped for what this
  /// fetch returns. The list is cleared only after every network call has
  /// succeeded, and refilled in the same synchronous block, so the UI never
  /// sees it empty and a failed fetch keeps the cache.
  static Future<void> importViewOnlyEventsToDB(
    String calendarId,
    ToDoDataBase db, {
    bool replace = false,
  }) async {
    if (_accessToken == null) throw Exception('Not signed in');

    // Fetch events
    final url = Uri.parse(
      "https://graph.microsoft.com/v1.0/me/calendars/$calendarId/events?\$select=id,subject,bodyPreview,start,end,recurrence,type,seriesMasterId",
    );

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $_accessToken"},
    );

    if (response.statusCode != 200) {
      return;
    }

    final data = jsonDecode(response.body);
    final events = List<Map<String, dynamic>>.from(data['value']);

    // Pre-fetch recurrence for occurrence instances (recurrence is only on the master)
    final Map<String, String> masterRepeatTypeCache = {};
    for (final e in events) {
      final masterId = e['seriesMasterId'] as String?;
      if (masterId != null && !masterRepeatTypeCache.containsKey(masterId)) {
        masterRepeatTypeCache[masterId] = await _fetchMasterRepeatType(
          masterId,
        );
      }
    }

    if (replace) db.outlookCalTasks.clear();

    for (final e in events) {
      if (e['start'] == null) continue;

      final startRaw = e['start']['dateTime'];
      if (startRaw == null) continue;

      final start = DateTime.parse(startRaw).toLocal();
      final dueDate = DateTimeUtilsHelper.formatDate(start);
      final dueTime = DateTimeUtilsHelper.formatTime(start);

      final eventId = e['id'] ?? _uuid.v4();

      // Check if already in DB (to avoid duplicates)
      // final alreadyExists = db.outlookCalTasks.any(
      //   (t) =>
      //       t.length > 15 &&
      //       ((t[15] == eventId && t[14] == calendarId) || t[16] == eventId),
      // );
      // Check if already exists in DB
      final existingIndex = db.outlookCalTasks.indexWhere(
        (t) => t.eventId == eventId && t.calendarId == calendarId,
      );

      final repeatType =
          e['recurrence'] != null
              ? _repeatTypeFromRecurrence(
                e['recurrence'] as Map<String, dynamic>?,
              )
              : masterRepeatTypeCache[e['seriesMasterId']] ?? 'none';

      if (existingIndex != -1) {
        // ✏️ Update existing record
        final t = db.outlookCalTasks[existingIndex];
        t.name = e['subject'] ?? 'Untitled Event';
        t.note = e['bodyPreview'] ?? '';
        t.dueDate = dueDate;
        t.dueTime = dueTime;
        t.category = 'None';
        t.priority = 'Low';
        t.repeatType = repeatType;
        t.reminderAmount = 10;
        t.reminderType = 'none';
        t.isStarred = false;
        t.subtasks = [];
        continue;
      }

      // ➕ Add as read-only event (marked so user knows it’s not editable)
      db.outlookCalTasks.add(
        CalendarEvent(
          name: e['subject'] ?? 'Untitled Event',
          completed: false,
          note: e['bodyPreview'] ?? '',
          dueDate: dueDate,
          dueTime: dueTime,
          category: 'None',
          priority: 'Low',
          repeatType: repeatType,
          reminderAmount: 10,
          reminderType: 'none',
          isStarred: false,
          createdAt: DateTime.now().toUtc().toString(),
          id: _uuid.v4(),
          subtasks: [],
          calendarId: calendarId,
          eventId: eventId,
          remoteEventId: eventId,
          source: "outlook",
          completedAt: "none",
        ),
      );
    }

    await db.saveOutlookCalTasks();
  }

  static Future<void> syncTasksToCalendar(
    ToDoDataBase db,
    String calendarID,
  ) async {
    //final calendar = await ensureToDoListCalendar();
    final tasksToSync = List<Task>.from(db.toDoList);
    for (var task in tasksToSync) {
      if (task.source == "repeat") continue;
      try {
        await addOrUpdateEvent(calendarID, task);
      } catch (_) {}
    }
  }

  static Future<void> syncTasksFromCalendar(ToDoDataBase db) async {
    final calID = db.syncToCalendars["outlook"];
    //db.outlookCalTasks.removeWhere((t) => t[14] == calID);
    //List<dynamic> events = await getEvents(calID);
    try {
      await importViewOnlyEventsToDB(calID, db, replace: true);
    } catch (_) {}
  }

  static Future<String> _fetchMasterRepeatType(String masterId) async {
    try {
      final url = Uri.parse(
        "https://graph.microsoft.com/v1.0/me/events/$masterId?\$select=recurrence",
      );
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $_accessToken"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _repeatTypeFromRecurrence(
          data['recurrence'] as Map<String, dynamic>?,
        );
      }
    } catch (_) {}
    return 'none';
  }

  static String _repeatTypeFromRecurrence(Map<String, dynamic>? recurrence) {
    if (recurrence == null) return 'none';
    final type = recurrence['pattern']?['type'] as String?;
    switch (type?.toLowerCase()) {
      case 'daily':
        return 'daily';
      case 'weekly':
        return 'weekly';
      case 'absolutemonthly':
      case 'relativemonthly':
        return 'monthly';
      case 'absoluteyearly':
      case 'relativeyearly':
        return 'yearly';
      default:
        return 'none';
    }
  }

  static Map<String, dynamic>? _buildRecurrenceRule(String? repeatType) {
    if (repeatType == null || repeatType == 'none' || repeatType == 'None') {
      return null;
    }

    String? pattern;
    switch (repeatType.toLowerCase()) {
      case 'daily':
        pattern = 'daily';
        break;
      case 'weekly':
        pattern = 'weekly';
        break;
      case 'monthly':
        pattern = 'absoluteMonthly';
        break;
      case 'yearly':
        pattern = 'absoluteYearly';
        break;
      default:
        return null;
    }

    return {
      "pattern": {"type": pattern, "interval": 1},
      "range": {
        "type": "noEnd", // repeats forever
        "startDate": DateTime.now().toIso8601String().split('T')[0],
      },
    };
  }
}
