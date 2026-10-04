import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/app_toggle.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/pages/settings_page.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/themes/app_theme.dart';
import 'package:to_do_app/themes/dark_mode.dart';
import 'package:to_do_app/themes/light_mode.dart';
import 'package:to_do_app/themes/theme_provider.dart';

import '../helpers/test_data.dart';

/// A database whose settings "save" is recorded instead of hitting Hive, so
/// widget tests do not depend on real disk I/O inside the fake-async zone.
class _RecordingDb extends ToDoDataBase {
  int saves = 0;
  @override
  void saveSettings() => saves++;
}

const teal = Color(0xFF0F766E);
const purple = Color(0xFF7C3AED);

void main() {
  group('accent colour derivation', () {
    test('default accent keeps the original amber palette exactly', () {
      expect(buildAppTheme(dark: false, accent: kAccent), same(lightMode));
      expect(buildAppTheme(dark: true, accent: kAccent), same(darkMode));
      expect(onAccentFor(kAccent), kOnAccent);
    });

    test('dark accents get white content, light accents a dark shade', () {
      expect(onAccentFor(teal), Colors.white);
      expect(onAccentFor(const Color(0xFF1D4ED8)), Colors.white);
      // Mid-tone green reads better with dark ink than with white.
      expect(onAccentFor(const Color(0xFF16A34A)), isNot(Colors.white));
      final onYellow = onAccentFor(const Color(0xFFFFEB3B));
      expect(onYellow.computeLuminance(), lessThan(0.1));
    });

    test('content colour is readable on every offered accent', () {
      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance(), l2 = b.computeLuminance();
        final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final c in kAccentChoices) {
        expect(
          contrast(c, onAccentFor(c)),
          greaterThanOrEqualTo(4.5),
          reason: 'accent $c',
        );
      }
    });

    test('offers the default plus seven others, all distinct and opaque', () {
      expect(kAccentChoices.first, kAccent);
      expect(kAccentChoices.length, 8);
      expect(kAccentChoices.toSet().length, 8);
      expect(kAccentChoices.every((c) => c.a == 1.0), isTrue);
    });

    test('a custom accent recolours light-mode primary and secondary', () {
      final t = buildAppTheme(dark: false, accent: teal);
      expect(t.colorScheme.primary, teal);
      expect(t.colorScheme.onPrimary, onAccentFor(teal));
      expect(t.colorScheme.secondary, accentSoftFor(teal, dark: false));
      expect(t.extension<AppColors>()!.accent, teal);
      expect(t.extension<AppColors>()!.onAccent, onAccentFor(teal));
      expect(t.brightness, Brightness.light);
    });

    test('a custom accent keeps the dark surface and recolours the accent', () {
      final t = buildAppTheme(dark: true, accent: teal);
      expect(t.colorScheme.primary, darkMode.colorScheme.primary);
      expect(t.colorScheme.surface, darkMode.colorScheme.surface);
      expect(t.extension<AppColors>()!.accent, teal);
      expect(t.brightness, Brightness.dark);
    });

    test('only accent tokens change; neutrals and priorities stay', () {
      final base = AppColors.light;
      final custom = base.withAccent(purple, dark: false);
      expect(custom.accent, purple);
      expect(custom.muted, base.muted);
      expect(custom.outline, base.outline);
      expect(custom.trackOff, base.trackOff);
      expect(custom.priorityHigh, base.priorityHigh);
    });

    test('the soft tint is a light wash in light mode, dark in dark mode', () {
      expect(
        accentSoftFor(teal, dark: false).computeLuminance(),
        greaterThan(0.6),
      );
      expect(
        accentSoftFor(teal, dark: true).computeLuminance(),
        lessThan(0.1),
      );
    });

    test('AppColors.lerp and copyWith carry the accent', () {
      final mid = AppColors.light.lerp(
        AppColors.light.withAccent(teal, dark: false),
        1,
      );
      expect(mid.accent, teal);
      expect(AppColors.light.copyWith(accent: purple).accent, purple);
    });
  });

  group('ThemeProvider accent', () {
    test('starts on the default accent in light mode', () {
      final p = ThemeProvider();
      expect(p.accent, kAccent);
      expect(p.themeData, same(lightMode));
    });

    test('can start with a saved accent', () {
      final p = ThemeProvider(accent: teal);
      expect(p.accent, teal);
      expect(p.themeData.colorScheme.primary, teal);
    });

    test('setAccent recolours the theme and notifies once', () {
      final p = ThemeProvider();
      var calls = 0;
      p.addListener(() => calls++);
      p.setAccent(purple);
      expect(p.accent, purple);
      expect(p.themeData.extension<AppColors>()!.accent, purple);
      expect(calls, 1);
    });

    test('setting the same accent does not notify', () {
      final p = ThemeProvider(accent: teal);
      var calls = 0;
      p.addListener(() => calls++);
      p.setAccent(teal);
      expect(calls, 0);
    });

    test('the accent survives switching between light and dark', () {
      final p = ThemeProvider()..setAccent(teal);
      p.toggleTheme();
      expect(p.isDarkMode, isTrue);
      expect(p.themeData.extension<AppColors>()!.accent, teal);
      p.toggleTheme();
      expect(p.isDarkMode, isFalse);
      expect(p.themeData.colorScheme.primary, teal);
    });

    test('choosing a new accent in dark mode stays dark', () {
      final p = ThemeProvider()..toggleTheme();
      p.setAccent(purple);
      expect(p.isDarkMode, isTrue);
      expect(p.themeData.extension<AppColors>()!.accent, purple);
    });

    test('going back to amber restores the original themes', () {
      final p = ThemeProvider()..setAccent(teal);
      p.setAccent(kAccent);
      expect(p.themeData, same(lightMode));
      p.toggleTheme();
      expect(p.themeData, same(darkMode));
    });
  });

  group('AppSettings.accentColor', () {
    test('defaults to amber', () {
      expect(const AppSettings().accentColor, kAccent.toARGB32());
      expect(AppSettings.fromMap({}).accentColor, kAccent.toARGB32());
    });

    test('round-trips through toMap/fromMap and copyWith', () {
      final s = const AppSettings().copyWith(accentColor: teal.toARGB32());
      expect(s.accentColor, teal.toARGB32());
      expect(AppSettings.fromMap(s.toMap()).accentColor, teal.toARGB32());
      expect(s.copyWith().accentColor, teal.toARGB32());
    });

    test('settings saved before accents existed still load', () {
      final old = const AppSettings().toMap()..remove('accentColor');
      expect(AppSettings.fromMap(old).accentColor, kAccent.toARGB32());
    });
  });

  group('widgets follow the accent', () {
    testWidgets('AppToggle uses the theme accent', (t) async {
      Color track() =>
          ((t.widget<AnimatedContainer>(find.byType(AnimatedContainer))
                      .decoration)
                  as BoxDecoration)
              .color!;

      await t.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(dark: false, accent: teal),
          home: Scaffold(body: AppToggle(value: true, onChanged: (_) {})),
        ),
      );
      expect(track(), teal);

      await t.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(dark: false, accent: purple),
          home: Scaffold(body: AppToggle(value: true, onChanged: (_) {})),
        ),
      );
      await t.pumpAndSettle();
      expect(track(), purple);
    });
  });

  group('Settings > Theme page', () {
    late _RecordingDb db;

    Future<ThemeProvider> pumpThemePage(
      WidgetTester t, {
      Color accent = kAccent,
    }) async {
      db = _RecordingDb();
      final provider = ThemeProvider(accent: accent);
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: Consumer<ThemeProvider>(
            builder:
                (_, p, __) =>
                    MaterialApp(theme: p.themeData, home: ThemePage(db: db)),
          ),
        ),
      );
      await t.pumpAndSettle();
      return provider;
    }

    Finder dot(Color c) => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).color == c,
    );

    testWidgets('shows one swatch per accent choice', (t) async {
      await pumpThemePage(t);
      for (final c in kAccentChoices) {
        expect(dot(c), findsOneWidget, reason: '$c');
      }
    });

    testWidgets('the current accent is marked selected', (t) async {
      await pumpThemePage(t, accent: teal);
      expect(
        find.descendant(of: dot(teal), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dot(purple), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('tapping a swatch applies it live', (t) async {
      final provider = await pumpThemePage(t);
      await t.tap(dot(purple));
      await t.pumpAndSettle();
      expect(provider.accent, purple);
      expect(
        t
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary,
        purple,
      );
      expect(
        find.descendant(of: dot(purple), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('the choice is stored in the settings and saved', (t) async {
      await pumpThemePage(t);
      await t.tap(dot(teal));
      await t.pumpAndSettle();
      expect(db.settings.accentColor, teal.toARGB32());
      expect(db.saves, 1);
    });

    testWidgets('picking the default amber restores the original theme', (
      t,
    ) async {
      final provider = await pumpThemePage(t, accent: teal);
      await t.tap(dot(kAccent));
      await t.pumpAndSettle();
      expect(provider.themeData, same(lightMode));
      expect(db.settings.accentColor, kAccent.toARGB32());
    });

    testWidgets('light and dark appearance rows still work', (t) async {
      final provider = await pumpThemePage(t, accent: purple);
      await t.tap(find.text('Dark'));
      await t.pumpAndSettle();
      expect(provider.isDarkMode, isTrue);
      expect(provider.accent, purple);
      await t.tap(find.text('Light'));
      await t.pumpAndSettle();
      expect(provider.isDarkMode, isFalse);
    });
  });

  group('accent persistence on disk', () {
    test('the saved accent is restored after a restart', () async {
      final env = await TestDb.open();
      addTearDown(env.dispose);
      env.db.settings = const AppSettings().copyWith(
        accentColor: purple.toARGB32(),
      );
      env.db.saveSettings();
      await Hive.box('meta').flush();

      final stored = Hive.box('meta').get('settings') as Map;
      final restored = AppSettings.fromMap(stored);
      expect(Color(restored.accentColor), purple);
      expect(ThemeProvider(accent: Color(restored.accentColor)).accent, purple);
    });
  });
}
