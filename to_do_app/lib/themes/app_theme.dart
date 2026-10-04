import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/themes/dark_mode.dart';
import 'package:to_do_app/themes/light_mode.dart';

/// The app theme for [dark] mode recoloured with [accent].
///
/// The default amber returns the hand-tuned [lightMode] / [darkMode] objects
/// unchanged. Any other accent keeps every neutral from those themes and
/// swaps only the accent-driven values. In light mode that includes the
/// Material `primary` / `secondary` roles (app bar, tabs, soft backgrounds),
/// which are amber-derived there; in dark mode `primary` is a near-black
/// surface, so only the accent tokens change.
ThemeData buildAppTheme({required bool dark, required Color accent}) {
  if (accent == kAccent) return dark ? darkMode : lightMode;

  final base = dark ? darkMode : lightMode;
  final ink = onAccentFor(accent);
  final soft = accentSoftFor(accent, dark: dark);
  final scheme =
      dark
          ? base.colorScheme
          : base.colorScheme.copyWith(
            primary: accent,
            onPrimary: ink,
            secondary: soft,
            onSecondary: ink,
          );
  return ThemeData(
    colorScheme: scheme,
    extensions: [
      (dark ? AppColors.dark : AppColors.light).withAccent(accent, dark: dark),
    ],
  );
}
