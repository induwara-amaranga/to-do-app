import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' show DetailedApiRequestError;
import 'package:http/http.dart' as http;
import 'package:msal_auth/msal_auth.dart';
import 'package:to_do_app/services/sync_problem.dart';

SyncProblemKind kind(Object? e, [SyncService s = SyncService.googleCalendar]) =>
    SyncProblem.classify(e, s).kind;

void main() {
  group('offline', () {
    test('socket and http client errors', () {
      expect(kind(const SocketException('x')), SyncProblemKind.offline);
      expect(kind(http.ClientException('x')), SyncProblemKind.offline);
    });
    test('google_sign_in network_error', () {
      expect(
        kind(PlatformException(code: 'network_error')),
        SyncProblemKind.offline,
      );
    });
  });

  group('missing permission', () {
    test('google 403 insufficient scopes', () {
      final e = DetailedApiRequestError(
        403,
        'Request had insufficient authentication scopes.',
      );
      expect(kind(e), SyncProblemKind.missingPermission);
      expect(kind(e, SyncService.googleDrive), SyncProblemKind.missingPermission);
    });
    test('google 403 for another reason is not a permission problem', () {
      final e = DetailedApiRequestError(403, 'Calendar API has not been used');
      expect(kind(e), SyncProblemKind.other);
    });
    test('graph 403', () {
      expect(
        kind(const ServiceHttpException(403, '{}'), SyncService.outlookCalendar),
        SyncProblemKind.missingPermission,
      );
    });
    test('msal declined scope', () {
      expect(
        kind(
          const MsalDeclinedScopeException(
            grantedScopes: [],
            declinedScopes: ['Calendars.ReadWrite'],
            message: 'declined',
            correlationId: null,
          ),
          SyncService.outlookCalendar,
        ),
        SyncProblemKind.missingPermission,
      );
    });
  });

  group('expired sign-in', () {
    test('401 from google and graph', () {
      expect(
        kind(DetailedApiRequestError(401, 'Invalid Credentials')),
        SyncProblemKind.expiredSignIn,
      );
      expect(
        kind(const ServiceHttpException(401, '{}'), SyncService.outlookCalendar),
        SyncProblemKind.expiredSignIn,
      );
    });
    test('no token at all', () {
      expect(kind(const NotSignedInException()), SyncProblemKind.expiredSignIn);
    });
  });

  group('cancelled and other', () {
    test('null error means the user closed sign-in', () {
      expect(kind(null), SyncProblemKind.cancelled);
    });
    test('msal user cancel', () {
      expect(
        kind(
          const MsalUserCancelException(message: 'x', correlationId: null),
          SyncService.outlookCalendar,
        ),
        SyncProblemKind.cancelled,
      );
    });
    test('unknown errors keep their text for the details line', () {
      final p = SyncProblem.classify(StateError('boom'), SyncService.googleDrive);
      expect(p.kind, SyncProblemKind.other);
      expect(p.detail, contains('boom'));
    });
    test('only permission and expiry problems offer sign in again', () {
      expect(
        SyncProblem.classify(const NotSignedInException(), SyncService.googleDrive)
            .needsSignIn,
        isTrue,
      );
      expect(
        SyncProblem.classify(const SocketException('x'), SyncService.googleDrive)
            .needsSignIn,
        isFalse,
      );
    });
  });
}
