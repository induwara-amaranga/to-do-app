import 'package:flutter/material.dart';

import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/themes/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider({Color accent = kAccent, bool dark = false, this.onChanged})
    : _accent = accent {
    _themeData = buildAppTheme(dark: dark, accent: _accent);
  }

  /// Called after the appearance (light/dark or accent) changes so it can be
  /// saved. Not called for the initial values.
  final void Function(bool dark, Color accent)? onChanged;

  late ThemeData _themeData;
  Color _accent;

  ThemeData get themeData => _themeData;
  Color get accent => _accent;

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    onChanged?.call(isDarkMode, _accent);
    notifyListeners();
  }

  void toggleTheme() {
    _themeData = buildAppTheme(dark: !isDarkMode, accent: _accent);
    onChanged?.call(isDarkMode, _accent);
    notifyListeners();
  }

  /// Recolours the current theme (light or dark) with [color].
  void setAccent(Color color) {
    if (color == _accent) return;
    _accent = color;
    _themeData = buildAppTheme(dark: isDarkMode, accent: _accent);
    onChanged?.call(isDarkMode, _accent);
    notifyListeners();
  }
}
