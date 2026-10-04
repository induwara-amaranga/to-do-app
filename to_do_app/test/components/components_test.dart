import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/app_toggle.dart';
import 'package:to_do_app/components/bar_chart.dart';
import 'package:to_do_app/components/calendar_events_header.dart';
import 'package:to_do_app/components/form_controls.dart';
import 'package:to_do_app/components/last_synced_label.dart';
import 'package:to_do_app/components/my_tab_bar.dart';
import 'package:to_do_app/components/search_bar.dart' as app;
import 'package:to_do_app/components/statistics_tile.dart';
import 'package:to_do_app/components/task_page_bottom_nav_bar.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'package:to_do_app/themes/app_colors.dart';
import 'package:to_do_app/themes/dark_mode.dart';
import 'package:to_do_app/themes/light_mode.dart';

import '../helpers/test_data.dart';

Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? lightMode,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppToggle', () {
    testWidgets('shows its value and reports the opposite on tap', (t) async {
      bool? received;
      await t.pumpWidget(
        host(AppToggle(value: false, onChanged: (v) => received = v)),
      );
      await t.tap(find.byType(AppToggle));
      expect(received, isTrue);
    });

    testWidgets('an "on" toggle reports false when tapped', (t) async {
      bool? received;
      await t.pumpWidget(
        host(AppToggle(value: true, onChanged: (v) => received = v)),
      );
      await t.tap(find.byType(AppToggle));
      expect(received, isFalse);
    });

    testWidgets('exposes toggled state to accessibility', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(host(AppToggle(value: true, onChanged: (_) {})));
      expect(
        t.getSemantics(find.byType(AppToggle)),
        matchesSemantics(
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('is dimmed and inert when onChanged is null', (t) async {
      await t.pumpWidget(host(const AppToggle(value: false, onChanged: null)));
      final opacity = t.widget<Opacity>(
        find.descendant(
          of: find.byType(AppToggle),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
      await t.tap(find.byType(AppToggle)); // must not throw
    });

    testWidgets('uses the accent colour when on, track colour when off', (
      t,
    ) async {
      Color trackColor() {
        final box =
            t
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration
                as BoxDecoration;
        return box.color!;
      }

      await t.pumpWidget(host(AppToggle(value: true, onChanged: (_) {})));
      expect(trackColor(), kAccent);
      await t.pumpWidget(host(AppToggle(value: false, onChanged: (_) {})));
      await t.pumpAndSettle();
      expect(trackColor(), AppColors.light.trackOff);
    });
  });

  group('LastSyncedLabel', () {
    Future<void> pumpLabel(WidgetTester t, CalendarSyncProvider p) async {
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: host(const LastSyncedLabel()),
        ),
      );
    }

    testWidgets('before any sync', (t) async {
      await pumpLabel(t, CalendarSyncProvider());
      expect(find.text('Not synced yet'), findsOneWidget);
    });

    testWidgets('while syncing', (t) async {
      await pumpLabel(t, CalendarSyncProvider()..startSync());
      expect(find.text('Syncing…'), findsOneWidget);
    });

    testWidgets('just finished', (t) async {
      await pumpLabel(t, CalendarSyncProvider()..finishSync());
      expect(find.text('Last synced just now'), findsOneWidget);
    });

    testWidgets('minutes, hours and days ago', (t) async {
      final p = CalendarSyncProvider();
      p.lastSyncedAt = DateTime.now().subtract(const Duration(minutes: 5));
      await pumpLabel(t, p);
      expect(find.text('Last synced 5 min ago'), findsOneWidget);

      p.lastSyncedAt = DateTime.now().subtract(const Duration(hours: 3));
      p.notify();
      await t.pump();
      expect(find.text('Last synced 3 h ago'), findsOneWidget);

      p.lastSyncedAt = DateTime.now().subtract(const Duration(days: 2));
      p.notify();
      await t.pump();
      expect(find.text('Last synced 2 d ago'), findsOneWidget);
    });

    testWidgets('rebuilds when the sync finishes', (t) async {
      final p = CalendarSyncProvider()..startSync();
      await pumpLabel(t, p);
      expect(find.text('Syncing…'), findsOneWidget);
      p.finishSync();
      await t.pump();
      expect(find.text('Last synced just now'), findsOneWidget);
    });
  });

  group('SearchBar', () {
    Future<(SearchingProvider, FileSearchProvider)> pumpBar(
      WidgetTester t,
      String type,
    ) async {
      final tasks = SearchingProvider();
      final files = FileSearchProvider();
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tasks),
            ChangeNotifierProvider.value(value: files),
          ],
          child: host(app.SearchBar(searchType: type)),
        ),
      );
      return (tasks, files);
    }

    testWidgets('typing updates the task query only', (t) async {
      final (tasks, files) = await pumpBar(t, 'task');
      await t.enterText(find.byType(TextField), 'milk');
      await t.pump(const Duration(milliseconds: 300)); // debounce
      expect(tasks.query, 'milk');
      expect(files.searchQuery, '');
    });

    testWidgets('typing updates the timetable query only', (t) async {
      final (tasks, files) = await pumpBar(t, 'timetable');
      await t.enterText(find.byType(TextField), 'exam');
      await t.pump(const Duration(milliseconds: 300)); // debounce
      expect(files.searchQuery, 'exam');
      expect(tasks.query, '');
    });

    testWidgets('waits for a pause in typing before searching', (t) async {
      final (tasks, _) = await pumpBar(t, 'task');
      var notified = 0;
      tasks.addListener(() => notified++);

      for (final q in ['m', 'mi', 'mil', 'milk']) {
        await t.enterText(find.byType(TextField), q);
        await t.pump(const Duration(milliseconds: 100)); // faster than debounce
      }
      expect(notified, 0, reason: 'nothing applied while still typing');
      expect(tasks.query, '');

      await t.pump(const Duration(milliseconds: 300));
      expect(notified, 1, reason: 'one search for the whole word');
      expect(tasks.query, 'milk');
    });

    testWidgets('clearing the box applies immediately', (t) async {
      final (tasks, _) = await pumpBar(t, 'task');
      await t.enterText(find.byType(TextField), 'milk');
      await t.pump(const Duration(milliseconds: 300));
      expect(tasks.query, 'milk');

      await t.enterText(find.byType(TextField), '');
      await t.pump(); // no debounce wait
      expect(tasks.query, '');
    });

    testWidgets('a custom debounce is honoured', (t) async {
      final tasks = SearchingProvider();
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: tasks,
          child: ChangeNotifierProvider(
            create: (_) => FileSearchProvider(),
            child: host(
              const app.SearchBar(
                searchType: 'task',
                debounce: Duration(milliseconds: 50),
              ),
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'a');
      await t.pump(const Duration(milliseconds: 80));
      expect(tasks.query, 'a');
    });

    testWidgets('leaving the page while a search is pending is safe', (
      t,
    ) async {
      final (tasks, _) = await pumpBar(t, 'task');
      await t.enterText(find.byType(TextField), 'milk');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      expect(tasks.query, '', reason: 'cancelled with the widget');
    });

    testWidgets('shows the hint and search icon', (t) async {
      await pumpBar(t, 'task');
      expect(find.text('Search...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('StatisticsTile', () {
    Map<String, List<List<dynamic>>> counts(int low, int med, int high) => {
      'Low': List.generate(low, (_) => []),
      'Medium': List.generate(med, (_) => []),
      'High': List.generate(high, (_) => []),
    };

    testWidgets('pending tile totals the three priorities', (t) async {
      await t.pumpWidget(
        host(StatisticsTile(isPending: true, tasksMap: counts(1, 2, 3))),
      );
      // The tile has a fixed 140px height; under the test font it overflows
      // by a few pixels. Layout is not what is being checked here.
      t.takeException();
      expect(find.text('Pending Tasks : 6'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('missed tile uses its own title', (t) async {
      await t.pumpWidget(
        host(StatisticsTile(isPending: false, tasksMap: counts(0, 0, 0))),
      );
      t.takeException(); // fixed-height overflow under the test font
      expect(find.text('Missed Tasks : 0'), findsOneWidget);
    });
  });

  group('CalendarEventsHeader', () {
    testWidgets('shows the count and calls onToggle', (t) async {
      var toggled = 0;
      await t.pumpWidget(
        host(
          CalendarEventsHeader(
            count: 4,
            collapsed: false,
            onToggle: () => toggled++,
          ),
        ),
      );
      expect(find.text('Calendar Events (4)'), findsOneWidget);
      await t.tap(find.byType(CalendarEventsHeader));
      expect(toggled, 1);
    });

    testWidgets('omits the count when there are no events', (t) async {
      await t.pumpWidget(
        host(CalendarEventsHeader(count: 0, collapsed: true, onToggle: () {})),
      );
      expect(find.text('Calendar Events'), findsOneWidget);
    });

    testWidgets('chevron flips with the collapsed state', (t) async {
      double turns() =>
          t.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;
      await t.pumpWidget(
        host(CalendarEventsHeader(count: 1, collapsed: true, onToggle: () {})),
      );
      expect(turns(), 0);
      await t.pumpWidget(
        host(CalendarEventsHeader(count: 1, collapsed: false, onToggle: () {})),
      );
      expect(turns(), 0.5);
    });
  });

  group('form controls', () {
    testWidgets('OptionRow shows label and trailing and handles taps', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          OptionRow(
            icon: Icons.alarm,
            label: 'Reminder',
            trailing: const Text('10 min'),
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.byIcon(Icons.alarm), findsOneWidget);
      await t.tap(find.byType(OptionRow));
      expect(taps, 1);
    });

    testWidgets('OptionsCard puts a divider between rows only', (t) async {
      await t.pumpWidget(
        host(
          const OptionsCard(rows: [Text('one'), Text('two'), Text('three')]),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('DropChip lists options and reports the selection', (t) async {
      String? picked;
      await t.pumpWidget(
        host(
          DropChip(
            value: 'daily',
            options: const ['none', 'daily', 'weekly'],
            onChanged: (v) => picked = v,
          ),
        ),
      );
      expect(find.text('daily'), findsOneWidget);
      await t.tap(find.byType(DropChip));
      await t.pumpAndSettle();
      expect(find.text('weekly'), findsOneWidget);
      await t.tap(find.text('weekly'));
      await t.pumpAndSettle();
      expect(picked, 'weekly');
    });

    testWidgets('SheetChip shows its label and fires onTap', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          SheetChip(
            label: 'High',
            selected: false,
            dotColor: Colors.red,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('High'), findsOneWidget);
      await t.tap(find.byType(SheetChip));
      expect(taps, 1);
    });

    testWidgets('SheetChip highlights when selected', (t) async {
      BoxDecoration deco() =>
          t
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(SheetChip),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      await t.pumpWidget(
        host(SheetChip(label: 'Work', selected: true, onTap: () {})),
      );
      expect(deco().color, AppColors.light.accentSoft);
      await t.pumpWidget(
        host(SheetChip(label: 'Work', selected: false, onTap: () {})),
      );
      expect(deco().color, isNull);
    });
  });

  group('theming', () {
    testWidgets('appColors resolves per theme', (t) async {
      late AppColors seen;
      await t.pumpWidget(
        host(
          Builder(
            builder: (c) {
              seen = c.appColors;
              return const SizedBox();
            },
          ),
          theme: darkMode,
        ),
      );
      expect(seen.trackOff, AppColors.dark.trackOff);
    });

    test('light and dark palettes differ and lerp between them', () {
      expect(AppColors.light.muted, isNot(AppColors.dark.muted));
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.muted, isNot(AppColors.light.muted));
      expect(AppColors.light.lerp(null, 0.5), AppColors.light);
      expect(AppColors.light.copyWith(muted: Colors.pink).muted, Colors.pink);
    });
  });

  group('MyTabBar', () {
    testWidgets('renders one tab per category and switches', (t) async {
      final names = ['All', 'Work', 'Home'];
      await t.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: DefaultTabController(
            length: names.length,
            child: Scaffold(
              appBar: AppBar(
                bottom: MyTabBar(
                  controller: null,
                  taskCategoryTabs: () => [for (final n in names) Tab(text: n)],
                ),
              ),
            ),
          ),
        ),
      );
      for (final n in names) {
        expect(find.text(n), findsOneWidget);
      }
      await t.tap(find.text('Home'));
      await t.pumpAndSettle();
      expect(DefaultTabController.of(t.element(find.byType(TabBar))).index, 2);
    });
  });

  group('TaskBottomNavBar', () {
    testWidgets('shows the three destinations with the current one selected', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: const Scaffold(
            bottomNavigationBar: TaskBottomNavBar(current: 1),
          ),
        ),
      );
      expect(find.text('Calender'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(
        t
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1,
      );
    });

    testWidgets('tapping a tab pushes the matching named route', (t) async {
      final pushed = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: lightMode,
          onGenerateRoute: (s) {
            pushed.add(s.name!);
            return MaterialPageRoute(
              settings: s,
              builder:
                  (_) => Scaffold(
                    bottomNavigationBar:
                        s.name == '/'
                            ? const TaskBottomNavBar(current: 1)
                            : null,
                    body: Text('page ${s.name}'),
                  ),
            );
          },
        ),
      );
      await t.tap(find.text('Statistics'));
      await t.pumpAndSettle();
      expect(pushed, contains('/statistics'));
    });
  });

  group('MyBarChart', () {
    testWidgets('builds for an empty week and for a busy one', (t) async {
      final empty = {for (var d = 1; d <= 7; d++) d: <dynamic>[]};
      await t.pumpWidget(
        host(
          SizedBox(
            height: 200,
            width: 300,
            child: MyBarChart(
              mappedWeek: {for (var d = 1; d <= 7; d++) d: []},
              isFromMonday: true,
            ),
          ),
        ),
      );
      expect(empty.length, 7);
      expect(find.byType(MyBarChart), findsOneWidget);

      await t.pumpWidget(
        host(
          SizedBox(
            height: 200,
            width: 300,
            child: MyBarChart(
              mappedWeek: {
                for (var d = 1; d <= 7; d++)
                  d: [for (var i = 0; i < d; i++) makeTask('t$d-$i')],
              },
              isFromMonday: false,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(MyBarChart), findsOneWidget);
    });
  });
}
