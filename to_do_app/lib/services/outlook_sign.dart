import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:msal_auth/msal_auth.dart';

class OutlookAuthService {
  // F-01: must match msal_config.json client_id
  static const _clientId = '6450d522-3a1c-4005-ae93-1fdc7f91aea2';
  static const _redirectUri =
      "msauth://com.example.to_do_app/Oust7aZi9rTbGkNnTUHkeg3V6WQ%3D";

  static String? _accessToken;
  static String? get accessToken => _accessToken;
  static set accessToken(String? token) => _accessToken = token;

  static final storage = FlutterSecureStorage();

  static late SingleAccountPca _pca;

  // The MSAL client is created once and reused; creating it is a platform
  // call, and it used to happen on every token request.
  static Future<void>? _initFuture;

  // B-02: only assign _accessToken after verification succeeds
  // static Future<bool> restoreLastSession() async {

  //   try {
  //     final savedToken = await storage.read(key: 'outlook_cal_accessToken');

  //     if (savedToken == null) {
  //       return false;
  //     }

  //     final silentToken = await acquireTokenSilently();

  //     if (silentToken != null) {
  //       _accessToken = silentToken;
  //       await storage.write(
  //         key: 'outlook_cal_accessToken',
  //         value: silentToken,
  //       );
  //       return true;
  //     }

  //     // Silent failed → token expired; clear stale token
  //     _accessToken = null;
  //     return false;
  //   } catch (e) {
  //     _accessToken = null;
  //     return false;
  //   }
  // }

  // F-09: delete stored token on sign-out
  static Future<void> signOut() async {
    try {
      await _pca.signOut();
      _accessToken = null;
      _tokenAt = null;
      await storage.delete(key: 'outlook_cal_accessToken');
    } catch (_) {}
  }

  static DateTime? _tokenAt;
  static const _tokenFreshness = Duration(minutes: 5);

  static Future<String?> acquireTokenSilently() async {
    final at = _tokenAt;
    if (_accessToken != null &&
        at != null &&
        DateTime.now().difference(at) < _tokenFreshness) {
      return _accessToken; // acquired moments ago (e.g. at start-up)
    }
    try {
      await init();
      final result = await _pca.acquireTokenSilent(
        scopes: [
          'https://graph.microsoft.com/User.Read',
          'https://graph.microsoft.com/Calendars.ReadWrite',
        ],
      );

      // F-04: never log the full token.
      // A successful silent acquire is a verified, fresh token: keep it so
      // calendar calls use it instead of the one from app start.
      _accessToken = result.accessToken;
      _tokenAt = DateTime.now();
      return result.accessToken;
    } catch (e) {
      return null;
    }
  }

  static Future<void> init() => _initFuture ??= _create();

  static Future<void> _create() async {
    try {
      _pca = await SingleAccountPca.create(
        clientId: _clientId,
        androidConfig: AndroidConfig(
          configFilePath: 'assets/msal_config.json',
          redirectUri: _redirectUri,
        ),
      );
    } catch (_) {
      _initFuture = null; // allow a later retry
    }
  }

  static Future<String?> signIn() async {
    try {
      final result = await _pca.acquireToken(
        scopes: [
          'https://graph.microsoft.com/User.Read',
          'https://graph.microsoft.com/Calendars.ReadWrite',
        ],
        prompt: Prompt.login,
      );

      // F-04: never log the full token
      _accessToken = result.accessToken;
      await storage.write(key: 'outlook_cal_accessToken', value: _accessToken);
      return _accessToken;
    } catch (e) {
      return null;
    }
  }

  // F-02: silent sign-in only at startup; interactive triggered by user action
  // B-01: assign _accessToken before writing to storage
  static Future<bool> initialize() async {
    try {
      await init();

      final silentToken = await acquireTokenSilently();

      if (silentToken != null) {
        _accessToken = silentToken;
        await storage.write(key: 'outlook_cal_accessToken', value: silentToken);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
