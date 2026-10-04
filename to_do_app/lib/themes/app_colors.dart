import 'package:flutter/material.dart';

/// The default amber brand accent. The user can pick another in Settings >
/// Theme; widgets read the live value from `context.appColors.accent`, not
/// from this constant. Identical in light and dark: in dark mode the theme's
/// `primary` is almost the same colour as the background, so anything that
/// must stay visible (FABs, selected nav item, headings) uses the accent.
const Color kAccent = Color(0xFFFFB31A);

/// Text/icon colour used on top of [kAccent].
const Color kOnAccent = Color(0xFF371B00);

/// Accent choices offered in Settings > Theme (first is the default).
const List<Color> kAccentChoices = [
  kAccent,
  Color(0xFF0F766E), // teal
  Color(0xFFDC2626), // red
  Color(0xFFB45309), // burnt orange
  Color(0xFFBE185D), // pink
  Color(0xFF16A34A), // green
  Color(0xFF1D4ED8), // blue
  Color(0xFF7C3AED), // purple
];

/// Readable text/icon colour for content drawn on [accent]: whichever of white
/// or a very deep shade of the accent's own hue has the higher contrast.
Color onAccentFor(Color accent) {
  if (accent == kAccent) return kOnAccent;
  final ink = HSLColor.fromColor(accent).withLightness(0.06).toColor();
  final accentLum = accent.computeLuminance();
  double contrast(Color c) {
    final l = c.computeLuminance();
    final hi = accentLum > l ? accentLum : l;
    final lo = accentLum > l ? l : accentLum;
    return (hi + 0.05) / (lo + 0.05);
  }

  return contrast(Colors.white) >= contrast(ink) ? Colors.white : ink;
}

/// A faint tint of [accent], used for selected chips and icon tiles.
Color accentSoftFor(Color accent, {required bool dark}) {
  return dark
      ? Color.lerp(const Color(0xFF1E1E1E), accent, 0.14)!
      : Color.lerp(Colors.white, accent, 0.22)!;
}

/// Design tokens that don't fit Material's [ColorScheme]. Mirrors the
/// variables in the Figma file's "Colors" collection (Light / Dark modes).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color trackOff;
  final Color muted;
  final Color outline;
  final Color priorityHigh;
  final Color priorityMedium;
  final Color priorityLow;

  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.trackOff,
    required this.muted,
    required this.outline,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
  });

  static const light = AppColors(
    accent: kAccent,
    onAccent: kOnAccent,
    accentSoft: Color(0xFFFFE7B0),
    trackOff: Color(0xFFBDBDBD),
    muted: Color(0xFF6B6B6B),
    outline: Color(0xFFE6E0D4),
    priorityHigh: Color(0xFFE53935),
    priorityMedium: Color(0xFFFFB300),
    priorityLow: Color(0xFF43A047),
  );

  static const dark = AppColors(
    accent: kAccent,
    onAccent: kOnAccent,
    accentSoft: Color(0xFF3A3220),
    trackOff: Color(0xFF5A5A5A),
    muted: Color(0xFFA8A8A8),
    outline: Color(0xFF333333),
    priorityHigh: Color(0xFFEF5350),
    priorityMedium: Color(0xFFFFC107),
    priorityLow: Color(0xFF66BB6A),
  );

  /// This palette recoloured for a user-chosen [accent]; every other token
  /// (greys, priority colours) is unchanged.
  AppColors withAccent(Color accent, {required bool dark}) => copyWith(
    accent: accent,
    onAccent: onAccentFor(accent),
    accentSoft:
        accent == kAccent
            ? (dark ? AppColors.dark.accentSoft : AppColors.light.accentSoft)
            : accentSoftFor(accent, dark: dark),
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? trackOff,
    Color? muted,
    Color? outline,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? priorityLow,
  }) => AppColors(
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentSoft: accentSoft ?? this.accentSoft,
    trackOff: trackOff ?? this.trackOff,
    muted: muted ?? this.muted,
    outline: outline ?? this.outline,
    priorityHigh: priorityHigh ?? this.priorityHigh,
    priorityMedium: priorityMedium ?? this.priorityMedium,
    priorityLow: priorityLow ?? this.priorityLow,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      trackOff: Color.lerp(trackOff, other.trackOff, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
