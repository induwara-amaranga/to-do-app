import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';

/// The services the app connects to.
enum BrandIcon { googleCalendar, outlook, deviceCalendar, googleDrive }

/// A brand mark on a white rounded tile (white keeps the full-colour logos
/// legible on both light and dark surfaces).
///
/// Google Calendar, Outlook and Google Drive use their logo artwork from
/// `assets/images`. The device calendar has no brand of its own, so it shows a
/// calendar glyph in its teal accent.
class BrandLogo extends StatelessWidget {
  final BrandIcon brand;
  final double size;

  const BrandLogo(this.brand, {super.key, this.size = 44});

  static const Color deviceCalendarColor = Color(0xFF00897B);

  String? get _asset {
    switch (brand) {
      case BrandIcon.googleCalendar:
        return 'assets/images/google/icons8-google-calendar-96.png';
      case BrandIcon.outlook:
        return 'assets/images/outlook/icons8-microsoft-outlook-2025-96.png';
      case BrandIcon.googleDrive:
        return 'assets/images/google/logo_drive_2020q4_color_2x_web_64dp.png';
      case BrandIcon.deviceCalendar:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyph = size * 0.64;
    final asset = _asset;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.23),
        border: Border.all(color: context.appColors.outline),
      ),
      child:
          asset != null
              ? Image.asset(
                asset,
                width: glyph,
                height: glyph,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              )
              : Icon(
                Icons.calendar_month,
                size: glyph,
                color: deviceCalendarColor,
              ),
    );
  }
}
