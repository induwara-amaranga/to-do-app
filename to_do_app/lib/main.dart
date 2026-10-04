import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
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
import 'package:to_do_app/providers/settings_providers.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/data_provider.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/outlook_sign.dart';
import 'package:to_do_app/themes/theme_provider.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';
import 'services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_app/config/app_config.dart';
import 'package:to_do_app/services/app_startup.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ToDoDataBase db = ToDoDataBase();
String? path;

/// Slow, network-bound start-up work. Runs after the first frame is on its
/// way; screens that need it await [AppStartup.ready].
Future<void> _initServices(AuthProvider auth, DataProvider data) async {
  await Future.wait([
    AppStartup.guard(
      () => Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      ),
    ),
    AppStartup.guard(() async {
      await GoogleAuthService.initApp();
      final user = GoogleAuthService.currentUser;
      if (user != null) {
        auth.setGoogleSignedIn(
          true,
          displayName: user.displayName ?? '',
          email: user.email,
          photoUrl: user.photoUrl ?? '',
        );
      }
    }),
    AppStartup.guard(() async {
      await OutlookAuthService.initialize();
      if (OutlookAuthService.accessToken != null) {
        auth.setOutlookSignedIn(true);
      }
    }),
    AppStartup.guard(NotificationService.init),
    AppStartup.guard(() async {
      // Times already on screen were computed with the saved zone; refresh
      // them only if detection found the device has moved.
      if (await AppStartup.detectTimeZone(db)) data.markTasksChanged();
    }),
  ]);

  // Scheduling needs both the notification plugin and the final time zone.
  await AppStartup.guard(
    () => NotificationService.scheduleDailySummaryNotifications(db),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Only what the first screen needs: local data.
  await Hive.initFlutter();
  await db.openBoxes();
  path = db.boxPath;

  if (db.isFreshInstall) {
    db.createInitialData();
    await db.updateDataBase();
  } else {
    db.loadData();
  }
  db.runMigrations();
  AppStartup.applySavedTimeZone(db);

  // Signed out until the background restore below finishes; it updates this.
  final authProvider = AuthProvider();
  final dataProvider = DataProvider(db);

  AppStartup.ready = _initServices(authProvider, dataProvider);

  runApp(
    MultiProvider(
      providers: [
        ...settingsBackedProviders(db),
        ChangeNotifierProvider(create: (_) => SearchingProvider()),
        ChangeNotifierProvider(create: (_) => CalendarSyncProvider()),
        ChangeNotifierProvider(create: (_) => FileSearchProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: dataProvider),
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
