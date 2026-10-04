import 'package:flutter/material.dart';

/// The amber brand accent. Identical in light and dark: in dark mode the
/// theme's `primary` is almost the same colour as the background, so anything
/// that must stay visible (FABs, selected nav item, headings) uses this.
const Color kAccent = Color(0xFFFFB31A);

/// Text/icon colour used on top of [kAccent].
const Color kOnAccent = Color(0xFF371B00);

/// Design tokens that don't fit Material's [ColorScheme]. Mirrors the
/// variables in the Figma file's "Colors" collection (Light / Dark modes).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color accentSoft;
  final Color trackOff;
  final Color muted;
  final Color outline;
  final Color priorityHigh;
  final Color priorityMedium;
  final Color priorityLow;

  const AppColors({
    required this.accentSoft,
    required this.trackOff,
    required this.muted,
    required this.outline,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
  });

  static const light = AppColors(
    accentSoft: Color(0xFFFFE7B0),
    trackOff: Color(0xFFBDBDBD),
    muted: Color(0xFF6B6B6B),
    outline: Color(0xFFE6E0D4),
    priorityHigh: Color(0xFFE53935),
    priorityMedium: Color(0xFFFFB300),
    priorityLow: Color(0xFF43A047),
  );

  static const dark = AppColors(
    accentSoft: Color(0xFF3A3220),
    trackOff: Color(0xFF5A5A5A),
    muted: Color(0xFFA8A8A8),
    outline: Color(0xFF333333),
    priorityHigh: Color(0xFFEF5350),
    priorityMedium: Color(0xFFFFC107),
    priorityLow: Color(0xFF66BB6A),
  );

  @override
  AppColors copyWith({
    Color? accentSoft,
    Color? trackOff,
    Color? muted,
    Color? outline,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? priorityLow,
  }) => AppColors(
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
