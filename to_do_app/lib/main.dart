import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/pages/calendar_page.dart';
import 'package:to_do_app/pages/filtered_tasks_page.dart';
import 'package:to_do_app/pages/calender_sync_page.dart';
import 'package:to_do_app/pages/manage_categories_page.dart';
import 'package:to_do_app/pages/saved_timetables_page.dart';
import 'package:to_do_app/pages/statistics_page.dart';
import 'package:to_do_app/pages/settings_page.dart';
import 'package:to_do_app/pages/task_page.dart';
import 'package:to_do_app/providers/calendar_sync_provider.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/file_sort_provider.dart';
import 'package:to_do_app/providers/data_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/outlook_sign.dart';
import 'package:to_do_app/themes/theme_provider.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_app/config/app_config.dart';
import 'package:to_do_app/utils/date_time_utils.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ToDoDataBase db = ToDoDataBase();
String? path;

Future<void> initLocalTimeZone() async {
  if (db.settings.timeZoneManuallySet) {
    final manual = DateTimeUtilsHelper.locationFromTimeZoneLabel(
      db.settings.timeZoneLabel,
    );
    if (manual != null) {
      tz.setLocalLocation(manual);
      return;
    }
    // Unrecognized label (e.g. corrupted data) — fall through to auto-detect.
  }
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    final tzName = tzInfo.identifier;
    final location = tz.getLocation(tzName);
    tz.setLocalLocation(location);
    db.settings = db.settings.copyWith(timeZoneLabel: tzName);
    db.saveSettings();
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await Hive.initFlutter();
  await Hive.openBox('mybox'); // legacy box for one-time migration
  await db.openBoxes();
  await db.clearLocalCalTasks();
  await db.clearGoogleCalTasks();
  await db.clearOutlookCalTasks();
  path = db.boxPath;

  if (db.isFreshInstall) {
    db.createInitialData();
    await db.updateDataBase();
  } else {
    db.loadData();
  }
  db.runMigrations();

  await GoogleAuthService.initApp();
  await OutlookAuthService.initialize();

  final authProvider = AuthProvider(
    isGoogleSignedIn: GoogleAuthService.currentUser != null,
    isOutlookSignedIn: OutlookAuthService.accessToken != null,
    displayName: GoogleAuthService.currentUser?.displayName ?? '',
    email: GoogleAuthService.currentUser?.email ?? '',
    photoUrl: GoogleAuthService.currentUser?.photoUrl ?? '',
  );

  try {
    await NotificationService.init();
  } catch (_) {}

  await initLocalTimeZone();

  try {
    await NotificationService.scheduleDailySummaryNotifications(db);
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GroupingProvider()),
        ChangeNotifierProvider(create: (_) => SortingProvider()),
        ChangeNotifierProvider(create: (_) => SearchingProvider()),
        ChangeNotifierProvider(create: (_) => CalendarSyncProvider()),
        ChangeNotifierProvider(create: (_) => FileSearchProvider()),
        ChangeNotifierProvider(create: (_) => FileSortProvider()),
        ChangeNotifierProvider(create: (_) => ViewProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => DataProvider(db)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: Provider.of<ThemeProvider>(context).themeData,
      initialRoute: '/',
      routes: {
        '/':
            (context) =>
                TaskPage(updateMissedTasks: true, db: db, filePath: path),
        '/savedTimetables': (context) => const SavedTimetablesPage(),
        '/manageCategories': (context) => const ManageCategoriesPage(),
        '/calendarSync': (context) => CalenderSyncPage(db: db),
        '/statistics': (context) => StatisticsPage(db: db),
        '/calendar': (context) => CalendarPage(db: db),
        '/settings': (context) => SettingsPage(db: db),
        '/filteredTasks':
            (context) => Filteredtaskspage(
              deleteFunction: null,
              onChanged: null,
              onTaskChanged: null,
              filterData: {},
              toDoList: [],
              categoryTypes: [],
            ),
      },
    );
  }
}
