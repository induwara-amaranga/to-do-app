import 'package:flutter/foundation.dart';

// F-07: Central auth state — single source of truth for all sign-in states.
class AuthProvider extends ChangeNotifier {
  bool _isGoogleSignedIn;
  bool _isOutlookSignedIn;
  String _displayName;
  String _email;
  String _photoUrl;

  AuthProvider({
    bool isGoogleSignedIn = false,
    bool isOutlookSignedIn = false,
    String displayName = '',
    String email = '',
    String photoUrl = '',
  }) : _isGoogleSignedIn = isGoogleSignedIn,
       _isOutlookSignedIn = isOutlookSignedIn,
       _displayName = displayName,
       _email = email,
       _photoUrl = photoUrl;

  bool get isGoogleSignedIn => _isGoogleSignedIn;
  bool get isOutlookSignedIn => _isOutlookSignedIn;
  String get displayName => _displayName;
  String get email => _email;
  String get photoUrl => _photoUrl;

  void setGoogleSignedIn(
    bool value, {
    String displayName = '',
    String email = '',
    String photoUrl = '',
  }) {
    if (!value) return signOutGoogle();
    _isGoogleSignedIn = true;
    _displayName = displayName;
    _email = email;
    _photoUrl = photoUrl;
    notifyListeners();
  }

  void setOutlookSignedIn(bool value) {
    _isOutlookSignedIn = value;
    notifyListeners();
  }

  void signOutGoogle() {
    _isGoogleSignedIn = false;
    _displayName = '';
    _email = '';
    _photoUrl = '';
    notifyListeners();
  }

  void signOutOutlook() {
    _isOutlookSignedIn = false;
    notifyListeners();
  }
}
