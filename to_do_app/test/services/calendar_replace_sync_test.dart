import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/services/google_calendar_service.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/local_calendar_service.dart';
import 'package:to_do_app/services/outlook_calendar_service.dart';
import 'package:to_do_app/services/outlook_sign.dart';

import '../helpers/test_data.dart';

gcal.Event gEvent(String id, String title) =>
    gcal.Event()
      ..id = id
      ..summary = title
      ..organizer = (gcal.EventOrganizer()..email = 'me@example.com')
      ..start =
          (gcal.EventDateTime()..dateTime = DateTime.utc(2026, 6, 20, 10));

http.Client googleClient({
  required int status,
  List<gcal.Event> events = const [],
}) {
  return MockClient((req) async {
    if (status != 200) return http.Response('boom', status);
    return http.Response(
      jsonEncode({'items': events.map((e) => e.toJson()).toList()}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Stand-in for a device_calendar Event (the import reads these fields
/// dynamically).
class _LocalEvent {
  final String title;
  final String eventId;
  final DateTime start;
  final String calendarId = 'cal-L';
  final String description = '';
  final dynamic recurrenceRule = null;
  _LocalEvent(this.title, this.eventId, this.start);
}

String outlookBody(List<(String id, String subject)> events) => jsonEncode({
  'value': [
    for (final e in events)
      {
        'id': e.$1,
        'subject': e.$2,
        'bodyPreview': '',
        'start': {'dateTime': '2026-06-20T10:00:00.0000000'},
        'recurrence': null,
      },
  ],
});

void main() {
  setUpAll(initTestTimeZone);

  late TestDb env;
  late ToDoDataBase db;

  setUp(() async {
    env = await TestDb.open();
    db = env.db;
    db.runMigrations();
  });
  tearDown(() async {
    GoogleAuthService.calendarApi = null;
    OutlookAuthService.accessToken = null;
    await Future.delayed(const Duration(milliseconds: 100));
    await env.dispose();
  });

  List<String> names(Iterable<dynamic> events) =>
      events.map<String>((e) => e.name as String).toList();

  group('Google view-only events', () {
    test('replace swaps the cache for exactly the fetched events', () async {
      db.googleCalTasks = [makeEvent('deleted remotely')];
      await db.saveGoogleCalTasks();

      await GoogleCalendarService.importViewOnlyEventsToDB(
        [gEvent('e1', 'Standup'), gEvent('e2', 'Review')],
        db,
        replace: true,
      );
      expect(names(db.googleCalTasks), ['Standup', 'Review']);

      db.loadGoogleCalTasks();
      expect(names(db.googleCalTasks), [
        'Standup',
        'Review',
      ], reason: 'on disk too');
    });

    test('replace with no events empties the cache and saves that', () async {
      db.googleCalTasks = [makeEvent('stale')];
      await db.saveGoogleCalTasks();
      await GoogleCalendarService.importViewOnlyEventsToDB(
        [],
        db,
        replace: true,
      );
      expect(db.googleCalTasks, isEmpty);
      db.loadGoogleCalTasks();
      expect(db.googleCalTasks, isEmpty);
    });

    test(
      'without replace, existing events are kept (sync-page behaviour)',
      () async {
        db.googleCalTasks = [makeEvent('other calendar')];
        await GoogleCalendarService.importViewOnlyEventsToDB([
          gEvent('e1', 'Standup'),
        ], db);
        expect(names(db.googleCalTasks), ['other calendar', 'Standup']);
      },
    );

    test('a null fetch result never clears the cache', () async {
      db.googleCalTasks = [makeEvent('cached')];
      await GoogleCalendarService.importViewOnlyEventsToDB(
        null,
        db,
        replace: true,
      );
      expect(names(db.googleCalTasks), ['cached']);
    });

    test(
      'only the Google box is written, not tasks or other calendars',
      () async {
        db.toDoList = [makeTask('unsaved task')]; // never saved
        db.localCalTasks = [makeEvent('unsaved local', source: 'local')];
        await GoogleCalendarService.importViewOnlyEventsToDB(
          [gEvent('e1', 'A')],
          db,
          replace: true,
        );
        db.loadData();
        expect(db.toDoList, isEmpty, reason: 'tasks box untouched');
        expect(db.localCalTasks, isEmpty, reason: 'local box untouched');
        expect(names(db.googleCalTasks), ['A']);
      },
    );

    test('syncing replaces the cache after a successful fetch', () async {
      db.syncToCalendars['google'] = 'cal-1';
      db.googleCalTasks = [makeEvent('old event')];
      GoogleAuthService.calendarApi = gcal.CalendarApi(
        googleClient(status: 200, events: [gEvent('n1', 'New event')]),
      );
      await GoogleCalendarService.syncTasksFromCalendars(db);
      expect(names(db.googleCalTasks), ['New event']);
    });

    test('a failed fetch (offline) keeps the cached events', () async {
      db.syncToCalendars['google'] = 'cal-1';
      db.googleCalTasks = [makeEvent('cached event')];
      GoogleAuthService.calendarApi = gcal.CalendarApi(
        googleClient(status: 503),
      );
      await expectLater(
        GoogleCalendarService.syncTasksFromCalendars(db),
        throwsA(anything),
      );
      expect(names(db.googleCalTasks), ['cached event']);
    });
  });

  group('Local calendar events', () {
    final day = DateTime(2026, 6, 20, 10);

    test('replace swaps the cache for exactly the fetched events', () async {
      db.localCalTasks = [makeEvent('gone', source: 'local')];
      await LocalCalendarService.importViewOnlyEventsToDB(
        [_LocalEvent('Dentist', 'l1', day)],
        db,
        replace: true,
      );
      expect(names(db.localCalTasks), ['Dentist']);
    });

    test('replace with no events empties the cache', () async {
      db.localCalTasks = [makeEvent('gone', source: 'local')];
      await LocalCalendarService.importViewOnlyEventsToDB(
        [],
        db,
        replace: true,
      );
      expect(db.localCalTasks, isEmpty);
    });

    test('a null fetch result keeps the cache', () async {
      db.localCalTasks = [makeEvent('cached', source: 'local')];
      await LocalCalendarService.importViewOnlyEventsToDB(
        null,
        db,
        replace: true,
      );
      expect(names(db.localCalTasks), ['cached']);
    });

    test('importing does not reload (and so discard) in-memory data', () async {
      // It used to call db.loadData(), replacing every in-memory list with the
      // disk copy mid-sync.
      final unsaved = makeTask('only in memory');
      db.toDoList = [unsaved];
      final listBefore = db.toDoList;
      await LocalCalendarService.importViewOnlyEventsToDB(
        [_LocalEvent('Dentist', 'l1', day)],
        db,
        replace: true,
      );
      expect(identical(db.toDoList, listBefore), isTrue);
      expect(db.toDoList.single, same(unsaved));
    });

    test('recurring instances import once', () async {
      await LocalCalendarService.importViewOnlyEventsToDB(
        [
          _LocalEvent('Gym', 'g1', DateTime(2026, 6, 22, 7)),
          _LocalEvent('Gym', 'g1', DateTime(2026, 6, 20, 7)),
          _LocalEvent('Gym', 'g1', DateTime(2026, 6, 24, 7)),
        ],
        db,
        replace: true,
      );
      expect(db.localCalTasks.length, 1);
    });
  });

  group('Outlook events', () {
    Future<void> run(http.Client client, Future<void> Function() body) =>
        http.runWithClient(body, () => client);

    test('replace swaps the cache for exactly the fetched events', () async {
      OutlookAuthService.accessToken = 'tok';
      db.outlookCalTasks = [makeEvent('gone', source: 'outlook')];
      await run(
        MockClient(
          (_) async => http.Response(outlookBody([('o1', 'Meeting')]), 200),
        ),
        () => OutlookCalendarService.importViewOnlyEventsToDB(
          'cal',
          db,
          replace: true,
        ),
      );
      expect(names(db.outlookCalTasks), ['Meeting']);
      db.loadOutlookCalTasks();
      expect(names(db.outlookCalTasks), ['Meeting']);
    });

    test('a failed fetch keeps the cached events', () async {
      OutlookAuthService.accessToken = 'tok';
      db.outlookCalTasks = [makeEvent('cached', source: 'outlook')];
      await run(
        MockClient((_) async => http.Response('nope', 500)),
        () => OutlookCalendarService.importViewOnlyEventsToDB(
          'cal',
          db,
          replace: true,
        ),
      );
      expect(names(db.outlookCalTasks), ['cached']);
    });

    test('signed out throws and keeps the cache', () async {
      OutlookAuthService.accessToken = null;
      db.outlookCalTasks = [makeEvent('cached', source: 'outlook')];
      await expectLater(
        OutlookCalendarService.importViewOnlyEventsToDB(
          'cal',
          db,
          replace: true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(names(db.outlookCalTasks), ['cached']);
    });

    test('without replace, existing events are kept', () async {
      OutlookAuthService.accessToken = 'tok';
      db.outlookCalTasks = [makeEvent('keep me', source: 'outlook')];
      await run(
        MockClient(
          (_) async => http.Response(outlookBody([('o1', 'Meeting')]), 200),
        ),
        () => OutlookCalendarService.importViewOnlyEventsToDB('cal', db),
      );
      expect(names(db.outlookCalTasks), ['keep me', 'Meeting']);
    });

    test(
      'the service uses the token held NOW, not the one at first use',
      () async {
        final seen = <String?>[];
        final client = MockClient((req) async {
          seen.add(req.headers['Authorization']);
          return http.Response(outlookBody([]), 200);
        });

        // First use of the service happens while signed out...
        OutlookAuthService.accessToken = null;
        await expectLater(
          OutlookCalendarService.importViewOnlyEventsToDB('cal', db),
          throwsA(isA<Exception>()),
        );

        // ...then the user signs in elsewhere, and later refreshes the token.
        OutlookAuthService.accessToken = 'first';
        await run(
          client,
          () => OutlookCalendarService.importViewOnlyEventsToDB('cal', db),
        );
        OutlookAuthService.accessToken = 'refreshed';
        await run(
          client,
          () => OutlookCalendarService.importViewOnlyEventsToDB('cal', db),
        );

        expect(seen, ['Bearer first', 'Bearer refreshed']);
      },
    );

    test('setAccessToken feeds the shared auth service', () {
      OutlookCalendarService.setAccessToken('abc');
      expect(OutlookAuthService.accessToken, 'abc');
    });
  });
}
