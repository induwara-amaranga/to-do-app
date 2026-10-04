import 'package:flutter/material.dart';

import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/themes/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider({Color accent = kAccent}) : _accent = accent {
    _themeData = buildAppTheme(dark: false, accent: _accent);
  }

  late ThemeData _themeData;
  Color _accent;

  ThemeData get themeData => _themeData;
  Color get accent => _accent;

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }

  void toggleTheme() {
    _themeData = buildAppTheme(dark: !isDarkMode, accent: _accent);
    notifyListeners();
  }

  /// Recolours the current theme (light or dark) with [color].
  void setAccent(Color color) {
    if (color == _accent) return;
    _accent = color;
    _themeData = buildAppTheme(dark: isDarkMode, accent: _accent);
    notifyListeners();
  }
}
