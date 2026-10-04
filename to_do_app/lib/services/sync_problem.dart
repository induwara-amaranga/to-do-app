import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:googleapis/calendar/v3.dart' show DetailedApiRequestError;
import 'package:http/http.dart' as http;
import 'package:msal_auth/msal_auth.dart';

/// The online services the app signs in to.
enum SyncService { googleCalendar, googleDrive, outlookCalendar }

extension SyncServiceInfo on SyncService {
  String get label => switch (this) {
    SyncService.googleCalendar => 'Google Calendar',
    SyncService.googleDrive => 'Google Drive',
    SyncService.outlookCalendar => 'Outlook Calendar',
  };

  bool get isGoogle => this != SyncService.outlookCalendar;

  /// What the service needs the user to allow, in plain words.
  String get permissionNeeded => switch (this) {
    SyncService.googleCalendar =>
      'see your calendars and add or change events in them',
    SyncService.googleDrive => 'save and restore your backup file',
    SyncService.outlookCalendar => 'read and change your calendar',
  };
}

/// Why a sign-in or sync step failed, as far as the user can act on it.
enum SyncProblemKind {
  /// The device could not reach the service.
  offline,

  /// Signed in, but the user never granted (or has since removed) a permission.
  missingPermission,

  /// The saved sign-in is no longer accepted (expired, revoked, password change).
  expiredSignIn,

  /// The user closed the sign-in screen.
  cancelled,

  /// Anything else; [SyncProblem.detail] holds the technical text.
  other,
}

/// Thrown for a non-success answer from a REST API that the app calls with
/// plain `http` (Microsoft Graph).
class ServiceHttpException implements Exception {
  final int status;
  final String body;
  const ServiceHttpException(this.status, this.body);

  @override
  String toString() => 'HTTP $status: $body';
}

/// Thrown when a step needs a signed-in account and there is none.
class NotSignedInException implements Exception {
  const NotSignedInException();

  @override
  String toString() => 'Not signed in';
}

class SyncProblem {
  final SyncProblemKind kind;
  final SyncService service;

  /// Technical text for the "details" line; empty when there is none.
  final String detail;

  const SyncProblem(this.kind, this.service, {this.detail = ''});

  /// Whether signing in again can fix it.
  bool get needsSignIn =>
      kind == SyncProblemKind.missingPermission ||
      kind == SyncProblemKind.expiredSignIn;

  /// Classifies [error]. A null error (a sign-in call that returned nothing
  /// and recorded no exception) is treated as the user closing the sign-in.
  static SyncProblem classify(Object? error, SyncService service) {
    final kind = _kindOf(error);
    return SyncProblem(
      kind,
      service,
      detail: kind == SyncProblemKind.other ? _describe(error) : '',
    );
  }

  static SyncProblemKind _kindOf(Object? e) {
    if (e == null) return SyncProblemKind.cancelled;

    if (e is SocketException ||
        e is HandshakeException ||
        e is TimeoutException ||
        e is http.ClientException) {
      return SyncProblemKind.offline;
    }
    if (e is NotSignedInException) return SyncProblemKind.expiredSignIn;

    if (e is DetailedApiRequestError) {
      final text = '${e.message} ${e.errors.map((x) => '${x.reason}')}';
      if (e.status == 401) return SyncProblemKind.expiredSignIn;
      if (e.status == 403 && _mentionsScope(text)) {
        return SyncProblemKind.missingPermission;
      }
      return SyncProblemKind.other;
    }

    if (e is ServiceHttpException) {
      if (e.status == 401) return SyncProblemKind.expiredSignIn;
      if (e.status == 403) return SyncProblemKind.missingPermission;
      return SyncProblemKind.other;
    }

    if (e is PlatformException) {
      final code = e.code.toLowerCase();
      final msg = '${e.message}'.toLowerCase();
      if (code == 'network_error' || msg.startsWith('7:')) {
        return SyncProblemKind.offline;
      }
      if (code == 'sign_in_canceled' || msg.contains('12501')) {
        return SyncProblemKind.cancelled;
      }
      if (code == 'sign_in_required') return SyncProblemKind.expiredSignIn;
      return SyncProblemKind.other;
    }

    if (e is MsalDeclinedScopeException) {
      return SyncProblemKind.missingPermission;
    }
    if (e is MsalUiRequiredException) return SyncProblemKind.expiredSignIn;
    if (e is MsalUserCancelException) return SyncProblemKind.cancelled;
    if (e is MsalClientException) {
      final code = e.errorCode.toLowerCase();
      if (code == 'device_network_not_available' || code == 'io_error') {
        return SyncProblemKind.offline;
      }
      if (code == 'no_current_account' || code == 'no_account_found') {
        return SyncProblemKind.expiredSignIn;
      }
    }
    if (e is MsalException) {
      final text = e.message.toLowerCase();
      if (text.contains('invalid_grant') ||
          text.contains('interaction_required') ||
          text.contains('expired')) {
        return SyncProblemKind.expiredSignIn;
      }
    }
    return SyncProblemKind.other;
  }

  static bool _mentionsScope(String text) {
    final t = text.toLowerCase();
    return t.contains('scope') ||
        t.contains('insufficientpermissions') ||
        t.contains('insufficient permission');
  }

  static String _describe(Object? e) {
    if (e is DetailedApiRequestError) return 'Google error ${e.status}: ${e.message}';
    if (e is MsalException) return e.message;
    return '$e';
  }
}
