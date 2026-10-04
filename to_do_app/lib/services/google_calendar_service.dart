import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import 'package:http/http.dart' as http;
//import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/calendar_event.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:uuid/uuid.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

final _uuid = Uuid();

class GoogleCalendarService {
  //static const _scopes = [gcal.CalendarApi.calendarScope];
  // A getter, not a `static final`: a final would capture whatever the auth
  // service held the first time this class was touched (null if that was
  // before sign-in), so signing in elsewhere would never reach it.
  static gcal.CalendarApi? get _calendarApi => GoogleAuthService.calendarApi;
  //static AuthClient? _client;
  static Map<String, String>? headers;
  static GoogleSignInAccount? _account;
  static final storage = FlutterSecureStorage();

  static const webClientId =
      '879200055223-f40a49a8tvse1ca2sngrudqh8r5f3ccg.apps.googleusercontent.com';
  static const androidClientId =
      '879200055223-ber902b42l2nh4bbg43kuvs3tq41dd9i.apps.googleusercontent.com';

  // /// Signs in with Google → authenticates Supabase → returns Calendar API client
  // static Future<gcal.CalendarApi?> initializeSignIn() async {

  //   final GoogleSignIn signIn = GoogleSignIn.instance;

  //   // Initialize Google Sign-In
  //   unawaited(
  //     signIn.initialize(clientId: iosClientId, serverClientId: webClientId),
  //   );

  //   // 🔐 Perform the sign-in
  //   final googleAccount = await signIn.authenticate(
  //     scopeHint: ['https://www.googleapis.com/auth/calendar'],
  //   );

  //   if (googleAccount == null) {
  //     return null;
  //   }

  //   // Request authorization for Calendar scope
  //   final googleAuthorization = await googleAccount.authorizationClient
  //       .authorizationForScopes(['https://www.googleapis.com/auth/calendar']);
  //   if (googleAuthorization == null) return null;

  //   final googleAuth = await googleAccount.authentication;

  //   final idToken = googleAuth.idToken;
  //   final accessToken = googleAuthorization.accessToken;

  //   if (idToken == null || accessToken == null) {
  //     return null;
  //   }

  //   // 🔗 Sign in to Supabase
  //   final response = await Supabase.instance.client.auth.signInWithIdToken(
  //     provider: OAuthProvider.google,
  //     idToken: idToken,
  //     accessToken: accessToken,
  //   );

  //   // 📆 Initialize Google Calendar API
  //   final calendarApi = await _getCalendarApi(accessToken);

  //   return calendarApi;
  // }

  // /// Helper: build an authenticated Google Calendar API client
  // static Future<gcal.CalendarApi> _getCalendarApi(String accessToken) async {
  //   final authClient = authenticatedClient(
  //     http.Client(),
  //     AccessCredentials(
  //       AccessToken(
  //         'Bearer',
  //         accessToken,
  //         DateTime.now().toUtc().add(const Duration(hours: 1)),
  //       ),
  //       null,
  //       [gcal.CalendarApi.calendarScope],
  //     ),
  //   );
  //   return gcal.CalendarApi(authClient);
  // }

  // static Future<bool> restoreLastSession() async {

  //   String? auth = await storage.read(key: 'google_cal_headers');

  //   if (auth == null) {
  //     return false;
  //   }
  //   Map<String, dynamic> header = jsonDecode(auth);

  //   //final headers = {'Authorization': auth, 'X-Goog-AuthUser': '0'};

  //   try {
  //     _calendarApi = await getCalendarApi(header.cast<String, String>());

  //     //_driveApi = drive.DriveApi(client);

  //     // test token
  //     //await _driveApi!.files.list(pageSize: 1);

  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  // static Future<Map<String, dynamic>?> initializeSignIn() async {

  //   // 1️⃣ Initialize GoogleSignIn
  //   await GoogleSignIn.instance.initialize(
  //     clientId: androidClientId,
  //     serverClientId: webClientId,
  //   );

  //   GoogleSignInAccount? account;

  //   // 2️⃣ Attempt SILENT sign-in first
  //   account = await GoogleSignIn.instance.attemptLightweightAuthentication();

  //   if (account != null) {
  //   } else {
  //     // 3️⃣ Fallback to UI sign-in
  //     account = await GoogleSignIn.instance.authenticate(
  //       scopeHint: ['https://www.googleapis.com/auth/calendar'],
  //     );
  //   }

  //   // 4️⃣ Now request OAuth headers (tokens)
  //   var headers = await account.authorizationClient.authorizationHeaders(
  //     ['https://www.googleapis.com/auth/calendar'],
  //     promptIfNecessary: false, // silent permission request
  //   );

  //   // 5️⃣ If tokens are null, ask for permission with popup
  //   if (headers == null) {
  //     headers = await account.authorizationClient.authorizationHeaders([
  //       'https://www.googleapis.com/auth/calendar',
  //     ], promptIfNecessary: true);
  //   }

  //   // 6️⃣ If STILL no headers → fail
  //   if (headers == null) {
  //     return null;
  //   }
  //   await storage.write(key: 'google_cal_headers', value: jsonEncode(headers));

  //   // 7️⃣ Build Calendar API
  //   final gcal.CalendarApi calendarApi = await getCalendarApi(headers);

  //   _calendarApi = calendarApi;
  //   _account = account;

  //   return {"api": calendarApi, "userName": account.displayName};
  // }

  // // /// Use this for signed-in user authentication (via Google Sign-In)
  // // static Future<void> fromAccessCredentials(
  // //   AccessCredentials credentials,
  // // ) async {
  // //   final client = authenticatedClient(http.Client(), credentials);
  // //   await initialize(client);
  // // }

  // /// Get user's Google calendars

  // static Future<gcal.CalendarApi> getCalendarApi(
  //   Map<String, String> headers,
  // ) async {
  //   final authClient = authenticatedClient(
  //     http.Client(),
  //     AccessCredentials(
  //       AccessToken(
  //         'Bearer',
  //         headers['Authorization']!.replaceFirst('Bearer ', ''),
  //         DateTime.now().toUtc().add(const Duration(hours: 1)),
  //       ),
  //       null,
  //       [gcal.CalendarApi.calendarScope],
  //     ),
  //   );

  //   return gcal.CalendarApi(authClient);
  // }

  /// Get events for a given calendar
  static Future<List<gcal.Event>> getEvents(String calendarId) async {
    _requireInit();
    final now = DateTime.now();
    final result = await _calendarApi!.events.list(
      calendarId,
      timeMin: now.subtract(const Duration(days: 60)).toUtc(),
      timeMax: now.add(const Duration(days: 60)).toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );
    return result.items ?? [];
  }

  /// Add or update a Google Calendar event from a google task
  static Future<void> addOrUpdateEvent(String calendarId, Task task) async {
    _requireInit();

    try {
      final dueDate = DateTimeUtilsHelper.parseDate(task.dueDate);
      final dueTime = DateTimeUtilsHelper.parseTime(task.dueTime!);
      if (dueDate == null) return;

      final startUnflagged = DateTimeUtilsHelper.combineDateAndTime(
        dueDate,
        dueTime ?? DateTime(0),
      );
      final start = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(
        startUnflagged,
      );
      final end = start.add(const Duration(minutes: 30));

      // If this task has already been linked to a Google event, patch it by id
      // directly. Listing the whole ±60-day window just to find the matching
      // id costs a full Calendar API round trip per task save, and the id we'd
      // be searching for is already sitting in remoteEventIds[1].
      final String knownEventId = (task.remoteEventIds[1] as String?) ?? '';
      if (knownEventId.isNotEmpty) {
        final event = gcal.Event(
          summary: task.name,
          description: task.note ?? '',
          start: gcal.EventDateTime(dateTime: start, timeZone: 'UTC'),
          end: gcal.EventDateTime(dateTime: end, timeZone: 'UTC'),
          id: knownEventId,
          recurrence: _buildRecurrenceRule(task.repeatType),
        );
        try {
          await _calendarApi!.events.patch(
            event,
            calendarId,
            knownEventId,
            sendUpdates: "all", // "none", "externalOnly", "all"
          );
          return;
        } catch (e) {
          // The event was deleted or moved calendars on the remote side —
          // drop the stale link and fall through to inserting a fresh one.
          task.remoteEventIds[1] = "";
        }
      }

      final event = gcal.Event(
        summary: task.name,
        description: task.note ?? '',
        start: gcal.EventDateTime(dateTime: start, timeZone: 'UTC'),
        end: gcal.EventDateTime(dateTime: end, timeZone: 'UTC'),
        recurrence: _buildRecurrenceRule(task.repeatType),
      );

      final created = await _calendarApi!.events.insert(event, calendarId);
      task.remoteEventIds[1] = created.id;
    } catch (_) {}
  }

  /// Delete a Google Calendar event
  static Future<void> deleteEvent(String calendarId, String eventId) async {
    _requireInit();
    try {
      await _calendarApi!.events.delete(calendarId, eventId);
    } catch (_) {}
  }

  /// Import events from Google Calendar into google DB
  static Future<void> importEventsToDB(
    String calendarId,
    ToDoDataBase db,
  ) async {
    _requireInit();
    final events = await getEvents(calendarId);

    for (final e in events) {
      if (e.start?.dateTime == null) continue;

      final start = e.start!.dateTime ?? e.start!.date?.toUtc();
      final dueDate = start!.toIso8601String().split('T')[0];
      final dueTime = start.toIso8601String().split('T')[1].split('.')[0];

      final existingIndex = db.toDoList.indexWhere(
        (t) => t.remoteEventIds[1] == e.id && t.localCalendarId == calendarId,
      );
      if (existingIndex != -1) {
        final t = db.toDoList[existingIndex];
        t.name = e.summary ?? 'Untitled Event';
        t.note = e.description ?? '';
        t.dueDate = dueDate;
        t.dueTime = dueTime;
        t.category = 'None';
        t.priority = 'Low';
        t.repeatType = 'none';
        t.reminderAmount = 10;
        t.reminderType = 'none';
        t.isStarred = false;
        t.subtasks = [];
        continue;
      }

      db.toDoList.add(
        Task(
          name: e.summary ?? 'Untitled Event',
          completed: false,
          note: e.description ?? '',
          dueDate: dueDate,
          dueTime: dueTime,
          category: 'None',
          priority: 'Low',
          repeatType: 'none',
          reminderAmount: 10,
          reminderType: 'none',
          isStarred: false,
          createdAt: DateTime.now().toUtc().toString(),
          id: _uuid.v4(),
          subtasks: [],
          localCalendarId: calendarId,
          localEventId: e.id ?? '',
          remoteEventIds: ["", e.id, ""],
          source: _account?.displayName ?? 'google',
          completedAt: "none",
          notificationIds: [],
        ),
      );
    }

    await db.updateDataBase();
  }

  /// Import a list of view-only events into the google DB
  static Future<void> importViewOnlyEventsToDB(
    List<dynamic>? events,
    ToDoDataBase db,
  ) async {
    if (events == null || events.isEmpty) {
      return;
    }

    for (final event in events) {
      if (event.start == null) continue;

      // Parse start time
      // DateTime? start;
      // if (event.start != null) {
      //   start = event.start!.dateTime ?? event.start!.date?.toLocal();
      // }
      // if (start == null) continue; // skip if we can't get a start time

      final startRaw = event.start!.dateTime ?? event.start!.date;
      final start = startRaw!.toUtc();
      final parts = start.toIso8601String().split('T');
      final dueDate = parts.first;
      final dueTime = parts.length > 1 ? parts[1].split('.')[0] : '00:00:00';

      // Safe access for calendarId and eventId
      final calendarId = event.organizer?.email ?? 'unknown_calendar';
      final eventId =
          event.id ?? _uuid.v4(); // fallback to uuid if event.id missing

      final taskDetails = {
        'taskName': event.summary ?? 'Untitled Event',
        'taskNote': event.description ?? '',
        'dueDate': dueDate,
        'dueTime': dueTime,
        'taskCategory': 'None',
        'taskPriority': 'Low',
        'repeatType': 'none',
        'remainderAmount': 10,
        'remainderType': 'none',
        'isStarred': false,
        'createdAt': DateTime.now().toUtc().toString(),
        'subTasks': [],
        'calendarId': calendarId,
        'eventId': eventId,
      };

      // Check if event already exists in DB
      final existingIndex = db.googleCalTasks.indexWhere(
        (task) =>
            task.calendarId == calendarId && task.remoteEventId == event.id,
      );

      if (existingIndex != -1) {
        // Update existing task
        final t = db.googleCalTasks[existingIndex];
        t.name = taskDetails['taskName'] as String;
        t.note = taskDetails['taskNote'] as String;
        t.dueDate = dueDate;
        t.dueTime = dueTime;
        t.category = taskDetails['taskCategory'] as String;
        t.priority = taskDetails['taskPriority'] as String;
        t.repeatType = taskDetails['repeatType'] as String;
        t.reminderAmount = taskDetails['remainderAmount'] as int;
        t.reminderType = taskDetails['remainderType'] as String;
        t.isStarred = taskDetails['isStarred'] as bool;
        t.subtasks = [];
        continue;
      }

      // Add new task
      db.googleCalTasks.add(
        CalendarEvent(
          name: taskDetails['taskName'] as String,
          completed: false,
          note: taskDetails['taskNote'] as String,
          dueDate: dueDate,
          dueTime: dueTime,
          category: taskDetails['taskCategory'] as String,
          priority: taskDetails['taskPriority'] as String,
          repeatType: taskDetails['repeatType'] as String,
          reminderAmount: taskDetails['remainderAmount'] as int,
          reminderType: taskDetails['remainderType'] as String,
          isStarred: taskDetails['isStarred'] as bool,
          createdAt: taskDetails['createdAt'] as String,
          id: _uuid.v4(),
          subtasks: [],
          calendarId: taskDetails['calendarId'] as String,
          eventId: taskDetails['eventId'] as String,
          remoteEventId: taskDetails['eventId'] as String,
          source: "google",
          completedAt: "none",
        ),
      );
    }

    await db.updateDataBase();
  }

  // /// Sync google tasks → Google Calendar
  // static Future<void> syncTasksToGoogle(
  //   ToDoDataBase db,
  //   String calendarId,
  // ) async {
  //   _requireInit();
  //   int count = 0;
  //   for (final task in List.from(db.toDoList)) {
  //     await addOrUpdateEvent(calendarId, task);
  //     count++;
  //   }
  // }

  /// Helper to ensure initialization
  static void _requireInit() {
    if (_calendarApi == null) {
      throw Exception(
        '❌ GoogleCalendarService not initialized. Call initialize() first.',
      );
    }
  }

  /// Create or get a Google Calendar by name
  static Future<gcal.Calendar?> createOrGetCalendar(
    List<gcal.CalendarListEntry> calendarList,
  ) async {
    _requireInit();

    try {
      // 1️⃣ List all existing calendars
      // final calendarList = await _calendarApi!.calendarList.list();

      // 2️⃣ Check if a calendar with the same name already exists
      final existing = calendarList.firstWhere(
        (c) => c.summary?.toLowerCase() == "ToDoList".toLowerCase(),
        orElse: () => gcal.CalendarListEntry(),
      );
      //existing=calendarFromListEntry

      if (existing.id != null) {
        return calendarFromListEntry(existing);
      }

      // 3️⃣ If not found, create a new calendar
      final newCalendar =
          gcal.Calendar()
            ..summary = "ToDoList"
            ..timeZone = 'UTC'; // adjust timezone if needed

      final createdCalendar = await _calendarApi!.calendars.insert(newCalendar);

      // 4️⃣ Optionally add it to calendar list (so it shows up in UI)
      await _calendarApi!.calendarList.insert(
        gcal.CalendarListEntry(id: createdCalendar.id),
      );

      return gcal.Calendar(
        id: createdCalendar.id,
        summary: createdCalendar.summary,
        timeZone: createdCalendar.timeZone,
      );
    } catch (_) {
      return null;
    }
  }

  static gcal.Calendar calendarFromListEntry(gcal.CalendarListEntry entry) {
    return gcal.Calendar()
      ..id = entry.id
      ..summary = entry.summary
      ..description = entry.description
      ..timeZone = entry.timeZone ?? 'UTC';
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

  static Future<void> syncTasksFromCalendars(ToDoDataBase db) async {
    final calID = db.syncToCalendars["google"];
    //db.googleCalTasks.removeWhere((t) => t[14] == calID);
    List<dynamic> events = await getEvents(calID);
    try {
      await importViewOnlyEventsToDB(events, db);
    } catch (_) {}
  }

  static List<String>? _buildRecurrenceRule(String? repeatType) {
    if (repeatType == null || repeatType == 'none' || repeatType == 'None') {
      return null;
    }

    switch (repeatType.toLowerCase()) {
      case 'daily':
        return ['RRULE:FREQ=DAILY;INTERVAL=1'];
      case 'weekly':
        return ['RRULE:FREQ=WEEKLY;INTERVAL=1'];
      case 'monthly':
        return ['RRULE:FREQ=MONTHLY;INTERVAL=1'];
      case 'yearly':
        return ['RRULE:FREQ=YEARLY;INTERVAL=1'];
      default:
        return null;
    }
  }
}
