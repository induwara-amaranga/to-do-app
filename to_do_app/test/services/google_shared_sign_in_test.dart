import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:to_do_app/services/google_calendar_service.dart';
import 'package:to_do_app/services/google_drive_service.dart';
import 'package:to_do_app/services/google_sign.dart';

/// A client that answers every request with an empty JSON list response.
http.Client fakeGoogleClient(List<Uri> seen) => MockClient((req) async {
  seen.add(req.url);
  return http.Response(
    jsonEncode({'items': [], 'files': []}),
    200,
    headers: {'content-type': 'application/json'},
  );
});

void main() {
  tearDown(() {
    GoogleAuthService.currentUser = null;
    GoogleAuthService.calendarApi = null;
    GoogleAuthService.driveApi = null;
  });

  group('one Google sign-in is shared by every service', () {
    test('Calendar service fails clearly while nobody is signed in', () {
      GoogleAuthService.calendarApi = null;
      expect(() => GoogleCalendarService.getEvents('primary'), throwsException);
    });

    test(
      'signing in AFTER the calendar service was first used still works',
      () async {
        // 1. The service is touched before sign-in (this used to freeze its
        //    API client at null for the rest of the app session).
        GoogleAuthService.calendarApi = null;
        await expectLater(
          GoogleCalendarService.getEvents('primary'),
          throwsException,
        );

        // 2. The user signs in somewhere else in the app.
        final seen = <Uri>[];
        GoogleAuthService.calendarApi = gcal.CalendarApi(
          fakeGoogleClient(seen),
        );

        // 3. The calendar service uses that session without a new sign-in.
        final events = await GoogleCalendarService.getEvents('primary');
        expect(events, isEmpty);
        expect(seen.single.path, contains('/calendars/primary/events'));
      },
    );

    test('the calendar service follows a refreshed API client', () async {
      final first = <Uri>[];
      final second = <Uri>[];
      GoogleAuthService.calendarApi = gcal.CalendarApi(fakeGoogleClient(first));
      await GoogleCalendarService.getEvents('a');

      // Token refresh builds a new client; the service must use the new one.
      GoogleAuthService.calendarApi = gcal.CalendarApi(
        fakeGoogleClient(second),
      );
      await GoogleCalendarService.getEvents('b');

      expect(first.length, 1);
      expect(second.length, 1);
    });

    test('Drive service returns null when signed out', () async {
      GoogleAuthService.driveApi = null;
      expect(await GoogleDriveService.createFolder(), isNull);
    });

    test('Drive service uses a sign-in done after it was first used', () async {
      GoogleAuthService.driveApi = null;
      expect(await GoogleDriveService.createFolder(), isNull);

      final seen = <Uri>[];
      GoogleAuthService.driveApi = drive.DriveApi(fakeGoogleClient(seen));
      await GoogleDriveService.createFolder();
      expect(seen, isNotEmpty, reason: 'the new Drive client was used');
    });

    test('ensureApisReady is false while signed out', () async {
      GoogleAuthService.currentUser = null;
      expect(await GoogleAuthService.ensureApisReady(), isFalse);
    });
  });
}
