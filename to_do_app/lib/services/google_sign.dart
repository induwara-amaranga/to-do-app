import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/sync_problem.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      // F-08: calendar.events is sufficient; avoids requesting full calendar settings access
      'https://www.googleapis.com/auth/calendar.events',
      // calendarList.list() (the calendar picker) is not covered by
      // calendar.events and fails with 403 "insufficient authentication scopes".
      'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
      // Lets the app create its own "ToDoList" calendar (calendars.insert) and
      // manage only calendars it created, not the user's other calendars.
      'https://www.googleapis.com/auth/calendar.app.created',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  static GoogleSignInAccount? currentUser;
  static gcal.CalendarApi? calendarApi;
  static drive.DriveApi? driveApi;

  // Access tokens last about an hour, so clients built in the last few minutes
  // are reused instead of asking the platform for a token before every call.
  static DateTime? _apisBuiltAt;

  /// The exception behind the most recent failed sign-in or token step, so the
  /// UI can tell the user why (offline, expired sign-in...) instead of only
  /// seeing a null result. Cleared when a sign-in or token step succeeds.
  static Object? lastError;
  static const _apiFreshness = Duration(minutes: 5);

  // F-02: silent restore only at startup; interactive sign-in triggered by user action
  static Future<void> initApp() async {
    try {
      currentUser = await signInSilently();
    } catch (_) {}
  }

  /// Call this at app startup — silently restores session if previously signed in
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      currentUser = await _googleSignIn.signInSilently();
      if (currentUser != null) await _initApis();
      return currentUser;
    } catch (e) {
      lastError = e;
      return null;
    }
  }

  /// Full sign-in flow (only needed if silent sign-in fails)
  static Future<GoogleSignInAccount?> signIn() async {
    lastError = null;
    try {
      currentUser = await _googleSignIn.signIn();
      if (currentUser != null) await _initApis();
      return currentUser;
    } catch (e) {
      lastError = e;
      return null;
    }
  }

  /// Call before every API use — ensures token is fresh
  static Future<void> _initApis() async {
    final client = await _getAuthClient();
    if (client == null) return;
    calendarApi = gcal.CalendarApi(client);
    driveApi = drive.DriveApi(client);
    _apisBuiltAt = DateTime.now();
  }

  /// Builds a fresh authenticated HTTP client (auto-refreshes token)
  static Future<_GoogleAuthClient?> _getAuthClient() async {
    try {
      final account = currentUser ?? _googleSignIn.currentUser;
      if (account == null) return null;

      final auth = await account.authentication; // auto-refreshes if expired
      if (auth.accessToken == null) throw const NotSignedInException();
      lastError = null;
      return _GoogleAuthClient({
        'Authorization': 'Bearer ${auth.accessToken}',
        'X-Goog-AuthUser': '0',
      });
    } catch (e) {
      lastError = e;
      return null;
    }
  }

  /// The one entry point every screen should use when it needs Google.
  ///
  /// Reuses the session if the user already signed in anywhere in the app,
  /// then tries a silent restore, and only shows the account picker as a last
  /// resort (and only when [interactive] is true). API clients are refreshed,
  /// and [auth] (if given) is updated so every screen sees the signed-in state.
  static Future<GoogleSignInAccount?> ensureSignedIn({
    AuthProvider? auth,
    bool interactive = true,
  }) async {
    var user = currentUser ?? _googleSignIn.currentUser;
    user ??= await signInSilently();
    if (user == null && interactive) user = await signIn();
    if (user == null) return null;

    currentUser = user;
    await ensureApisReady();
    if (auth != null && !(auth.isGoogleSignedIn && auth.email == user.email)) {
      auth.setGoogleSignedIn(
        true,
        displayName: user.displayName ?? user.email,
        email: user.email,
        photoUrl: user.photoUrl ?? '',
      );
    }
    return user;
  }

  /// Call this before any API call to ensure apis are fresh
  static Future<bool> ensureApisReady() async {
    if (currentUser == null) return false;
    final builtAt = _apisBuiltAt;
    final fresh =
        calendarApi != null &&
        driveApi != null &&
        builtAt != null &&
        DateTime.now().difference(builtAt) < _apiFreshness;
    if (!fresh) await _initApis();
    return calendarApi != null && driveApi != null;
  }

  /// Get a fresh access token (auto-refreshes if expired)
  static Future<String?> getAccessToken() async {
    try {
      final account = _googleSignIn.currentUser ?? await signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    currentUser = null;
    calendarApi = null;
    driveApi = null;
    _apisBuiltAt = null;
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> headers;
  // B-03: static singleton prevents a new connection pool per API call
  static final http.Client _inner = http.Client();

  _GoogleAuthClient(this.headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request..headers.addAll(headers));
}
