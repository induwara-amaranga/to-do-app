import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:to_do_app/utils/string_utils.dart';
import 'package:to_do_app/utils/log.dart';

//import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    //init timezone handling
    //tz.initializeTimeZones();
    //var currentTimeZone = await FlutterTimezone.getLocalTimezone();
    //String zoneString = currentTimeZone.identifier;
    //logd("detected zone is=====================>$zoneString");
    //tz.setLocalLocation(tz.getLocation(zoneString));
    //android intialization settings
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iOSInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static Future<bool> isNotificationPermissionGranted() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? granted = await androidPlugin?.areNotificationsEnabled();
      return granted ?? false;
    }

    // iOS always prompts via requestPermissions, assume granted if init succeeded
    return true;
  }

  //show android dialog to request notification permission, returns true if granted, false if denied or permanently denied
  static Future<bool> requestNotificationPermission() async {
    bool granted = false;

    if (Platform.isAndroid) {
      // Request basic notification permission (Android 13+)
      final bool? result =
          await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();

      granted = result ?? false;
      logd("Android notification permission granted: $granted");

      // Request exact alarm permission (Android 12+)
      final bool? exactAlarmGranted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestExactAlarmsPermission();

      logd("Exact alarm permission granted: $exactAlarmGranted");
    } else if (Platform.isIOS) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      granted = result ?? false;
      logd("iOS notification permission granted: $granted");
    }

    return granted;
  }

  static NotificationDetails notificationDetails(
    String priority,
    bool isFullscreen, {
    bool showOnLockScreen = true,
    String? notifRingtoneUri,
    String? alarmRingtoneUri,
  }) {
    final visibility =
        showOnLockScreen
            ? NotificationVisibility.public
            : NotificationVisibility.secret;

    // Full-screen (alarm-like) reminders use the alarm ringtone; regular
    // reminders use the notification ringtone. Settings default to
    // placeholder names ("Chime"/"Radar") until the user actually picks a
    // tone via RingtonePicker, at which point they become content:// URIs.
    final String? soundUri = isFullscreen ? alarmRingtoneUri : notifRingtoneUri;
    final AndroidNotificationSound? sound =
        (soundUri != null && soundUri.startsWith('content://'))
            ? UriAndroidNotificationSound(soundUri)
            : null;
    // Android channels are immutable once created — a custom sound needs
    // its own channel id, or the first-ever sound wins forever.
    String channelId(String base) =>
        sound == null ? base : '${base}_${soundUri.hashCode}';
    switch (priority) {
      case "High":
        return NotificationDetails(
          android: AndroidNotificationDetails(
            channelId('high_task_channel_id'),
            'High Priority Task Notifications',
            channelDescription: 'Notifications for high priority to-do tasks',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: sound,
            enableVibration: true,
            fullScreenIntent: isFullscreen,
            visibility: visibility,
            color: const Color.fromARGB(255, 255, 161, 154),
            vibrationPattern: Int64List.fromList([0, 1000, 500, 2000]),
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'mark_done',
                '✅ Done',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'working',
                '🕒 Working on it',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'dismiss',
                '❌ Dismiss',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(),
        );
      case "Medium":
        return NotificationDetails(
          android: AndroidNotificationDetails(
            channelId('medium_task_channel_id'),
            'Medium Priority Task Notifications',
            channelDescription: 'Notifications for medium priority to-do tasks',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: sound,
            visibility: visibility,
            color: const Color.fromARGB(255, 253, 244, 170),
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'mark_done',
                '✅ Done',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'working',
                '🕒 Working on it',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'dismiss',
                '❌ Dismiss',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(),
        );
      case "Low":
        return NotificationDetails(
          android: AndroidNotificationDetails(
            'low_task_channel_id',
            'Low Priority Task Notifications',
            channelDescription: 'Notifications for low priority to-do tasks',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false,
            visibility: visibility,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'mark_done',
                '✅ Done',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'working',
                '🕒 Working on it',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'dismiss',
                '❌ Dismiss',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(),
        );
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId('task_channel_id'),
        'Task Notifications',
        channelDescription: 'Notifications for to-do tasks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: sound,
        visibility: visibility,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'mark_done',
            '✅ Done',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'working',
            '🕒 Working on it',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            '❌ Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  static Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    logd("instant notification showing");
    return _notifications.show(
      id,
      title,
      body,
      notificationDetails("Low", false),
    );
  }

  static Future<void> sheduledTimeNotification({
    required List<dynamic> payload,
    required int id,
    required String title,
    required String body,
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minutes,
    required String priority,
    required String repeatType,
    required bool isFullScreen,
    bool showOnLockScreen = true,
    String? notifRingtoneUri,
    String? alarmRingtoneUri,
  }) async {
    if (!await isNotificationPermissionGranted()) {
      final bool granted = await requestNotificationPermission();
      if (!granted) return;
    }
    final scheduledDateTime = tz.TZDateTime(
      tz.UTC, // 👈 local time (important)
      year,
      month,
      day,
      hour,
      minutes,
    );

    final now = tz.TZDateTime.now(tz.UTC);

    logd(
      "------------------------------------------Scheduling notification for $scheduledDateTime | now=$now | repeat=$repeatType -----------",
    );

    if (scheduledDateTime.isBefore(now)) {
      logd("⚠️ Scheduled time is in the past! Reminder not set.");
      return;
    }

    /// 🔁 Decide repeat behavior
    DateTimeComponents? matchComponents;

    switch (repeatType.toLowerCase()) {
      case "daily":
        matchComponents = DateTimeComponents.time;
        break;

      case "weekly":
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        break;

      case "monthly":
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
        break;

      case "none":
      default:
        matchComponents = null; // one-time notification
    }
    if (await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestFullScreenIntentPermission() ==
        false) {
      logd("Full screen intent permission denied");
    }

    try {
      final _title =
          "$title ${priority == "High"
              ? "🔴"
              : priority == "Low"
              ? "🟢"
              : "🟡"}";

      await _notifications.zonedSchedule(
        id,
        _title,
        body,
        scheduledDateTime,
        notificationDetails(
          priority,
          isFullScreen,
          showOnLockScreen: showOnLockScreen,
          notifRingtoneUri: notifRingtoneUri,
          alarmRingtoneUri: alarmRingtoneUri,
        ),
        payload: payload.toString(),

        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,

        // 🔁 THIS enables repeating
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      logd("Scheduling error: $e");
    }
  }

  static DateTime remainderDateTime(
    DateTime dueDate,
    DateTime dueTime,
    String remainderType,
    int remainderAmount,
  ) {
    // Combine due date and time
    DateTime fullDueDateTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTime.hour,
      dueTime.minute,
    );

    // Subtract remainder
    switch (remainderType) {
      case "minutes":
        return fullDueDateTime.subtract(Duration(minutes: remainderAmount));
      case "hours":
        return fullDueDateTime.subtract(Duration(hours: remainderAmount));
      case "days":
        return fullDueDateTime.subtract(Duration(days: remainderAmount));
      case "weeks":
        return fullDueDateTime.subtract(Duration(days: 7 * remainderAmount));
      default:
        // if type is unknown, return the original date-time
        return fullDueDateTime;
    }
  }

  // @pragma('vm:entry-point')
  // static void notificationTapBackgroundAlt(
  //   NotificationResponse response,
  // ) async {
  //   // IMPORTANT: background isolate needs plugin initialization
  //   WidgetsFlutterBinding.ensureInitialized();
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();

  //   // Write data to confirm background execution
  //   await prefs.setBool('notification_background_ran', true);
  //   await prefs.setString(
  //     'last_notification_action',
  //     response.actionId ?? 'no_action',
  //   );

  //   logd('Background action executed');
  // }

  @pragma('vm:entry-point')
  static Future<void> notificationTapBackground(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();

    logd('BACKGROUND action: ${response.actionId}');

    try {
      final id = response.id;
      final actionId = response.actionId;
      logd("get list");
      final payload = StringUtils.listFromString(response.payload!);
      logd("Notification payload: $payload");
      final DateTime now = DateTime.now();

      if (payload[1] == 'High') {
        // showDialog(
        //   context: navigatorKey.currentContext!,
        //   builder:
        //       (ctx) => AlertDialog(
        //         title: const Text("⚠️ High Priority Task"),
        //         content: Text(payload[4]), // task name
        //         actions: [
        //           TextButton(
        //             onPressed: () => Navigator.of(ctx).pop(),
        //             child: const Text("OK"),
        //           ),
        //         ],
        //       ),
        //);
      }

      if (actionId == 'mark_done') {
        logd("✅ Task $payload marked as done!");
        // TODO: update database / provider
      } else if (actionId == 'working') {
        logd("🕒 Working on task $payload");
        DateTime dueDateTime = DateTimeUtilsHelper.parseDateTime(payload[2]);

        //final payload = response.payload;
      } else if (actionId == 'dismiss') {
        logd("❌ Dismissed task $payload");

        List<Object> ids =
            payload.length > 5 ? StringUtils.listFromString(payload[5]) : [];

        for (Object remId in ids) {
          try {
            final int parsedId = int.parse(remId.toString().trim());
            await cancelNotification(parsedId);
          } catch (e) {
            logd("Failed to parse/cancel notification id '$remId': $e");
          }
        }
      } else {
        logd("Notification tapped normally");
      }
    } catch (e) {
      logd("---------action error : $e------");
    }
  }

  @pragma('vm:entry-point')
  static void onNotificationResponse(NotificationResponse response) async {
    logd("---------------------------------");

    try {
      final id = response.id;
      final actionId = response.actionId;
      logd("get list");
      final payload = StringUtils.listFromString(response.payload!);
      logd("Notification payload: $payload");
      final DateTime now = DateTime.now();

      if (payload[1] == 'High') {
        // showDialog(
        //   context: navigatorKey.currentContext!,
        //   builder:
        //       (ctx) => AlertDialog(
        //         title: const Text("⚠️ High Priority Task"),
        //         content: Text(payload[4]), // task name
        //         actions: [
        //           TextButton(
        //             onPressed: () => Navigator.of(ctx).pop(),
        //             child: const Text("OK"),
        //           ),
        //         ],
        //       ),
        //);
      }

      if (actionId == 'mark_done') {
        logd("✅ Task $payload marked as done!");
        // TODO: update database / provider
      } else if (actionId == 'working') {
        logd("🕒 Working on task $payload");
        DateTime dueDateTime = DateTimeUtilsHelper.parseDateTime(payload[2]);
        // switch (payload[1]) {
        //   case 'High':
        //     DateTime newTime = now.add(const Duration(minutes: 1));
        //     if (!newTime.isBefore(dueDateTime)) {
        //       newTime = dueDateTime;
        //     }
        //     rescheduleNotification(
        //       payload: payload,
        //       id: id!,
        //       title: payload[3],
        //       body: payload[4],
        //       newTime: newTime,
        //     );
        //     break;
        //   case 'Medium':
        //     DateTime newTime = now.add(const Duration(minutes: 60));
        //     if (!newTime.isBefore(dueDateTime)) {
        //       newTime = dueDateTime;
        //     }
        //     rescheduleNotification(
        //       payload: payload,
        //       id: id!,
        //       title: payload[3],
        //       body: payload[4],
        //       newTime: newTime,
        //     );
        //     break;
        //   case 'Low':
        //     // DateTime newTime = now.add(const Duration(minutes: 10));
        //     // if (!newTime.isBefore(dueDateTime)) {
        //     //   newTime = dueDateTime;
        //     // }
        //     // //logd("low - secheduled");
        //     // rescheduleNotification(
        //     //   payload: payload,
        //     //   id: id!,
        //     //   title: payload[3],
        //     //   body: payload[4],
        //     //   newTime: newTime,
        //     // );
        //     break;
        //   default:
        //     logd("Unknown priority level: $payload");
        // }

        //final payload = response.payload;
      } else if (actionId == 'dismiss') {
        logd("❌ Dismissed task $payload");
        List<Object> ids =
            payload.length > 5 ? StringUtils.listFromString(payload[5]) : [];
        for (Object remId in ids) {
          await cancelNotification(remId as int);
        }
        //await cancelNotification(id!);
      } else {
        logd("Notification tapped normally");
      }
    } catch (e) {
      logd("---------action error : $e------");
    }
  }

  // Reschedule a notification
  static Future<void> rescheduleNotification({
    required List<dynamic> payload,
    required int id,
    required String title,
    required String body,
    required DateTime newTime,
    required String repeatType,
    required bool isFullscreen,
  }) async {
    // 1️⃣ Cancel the old notification
    await cancelNotification(id);

    // 2️⃣ Schedule the new one
    await sheduledTimeNotification(
      isFullScreen: isFullscreen,
      repeatType: repeatType,
      payload: payload,
      id: id,
      title: title,
      body: body,
      year: newTime.year,
      month: newTime.month,
      day: newTime.day,
      hour: newTime.hour,
      minutes: newTime.minute,
      priority: payload[1],
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  //function to cancel specific notification
  static Future<void> cancelNotification(int id) async {
    logd("Attempting to cancel notification with id: $id");
    try {
      await _notifications.cancel(id);
      logd("notification $id cancelled");
    } catch (e) {
      logd("Error cancelling notification $id: $e");
    }
    //logd("canceled: $id");
    //if there is no notification with id, nothing happens
  }

  // ── Daily summary notifications (Settings › Notifications › Behavior) ───
  // Fixed IDs so re-running this is idempotent (reschedule cancels+replaces
  // the same notification rather than piling up new ones).
  static const int _morningPlanId = 900001;
  static const int _eveningReviewId = 900002;
  static const int _taskOverviewId = 900003;

  /// Schedules (or cancels, if the toggle is off) the three daily summary
  /// notifications. Safe to call repeatedly — call at app startup and again
  /// whenever the relevant settings change.
  static Future<void> scheduleDailySummaryNotifications(ToDoDataBase db) async {
    await _scheduleOrCancelDaily(
      db: db,
      enabled: db.settings.morningPlan,
      id: _morningPlanId,
      hour: 7,
      minute: 30,
      title: "Good morning! ☀️",
      body: "Here's your plan for today. Tap to review your tasks.",
    );
    await _scheduleOrCancelDaily(
      db: db,
      enabled: db.settings.eveningReview,
      id: _eveningReviewId,
      hour: 21,
      minute: 0,
      title: "Evening Review 🌙",
      body: "How did today go? Tap to review what you completed.",
    );
    await _scheduleOrCancelDaily(
      db: db,
      enabled: db.settings.taskOverview,
      id: _taskOverviewId,
      hour: 12,
      minute: 0,
      title: "Daily Task Overview 📋",
      body: "Here's a look at your tasks for today.",
    );
  }

  static Future<void> _scheduleOrCancelDaily({
    required ToDoDataBase db,
    required bool enabled,
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!enabled) {
      await cancelNotification(id);
      return;
    }
    if (!await isNotificationPermissionGranted()) {
      final granted = await requestNotificationPermission();
      if (!granted) return;
    }
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        notificationDetails(
          "Medium",
          false,
          showOnLockScreen: db.settings.lockScreenReminder,
          notifRingtoneUri: db.settings.notifRingtone,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      );
    } catch (e) {
      logd("Failed to schedule daily summary notification $id: $e");
    }
  }

  static Future<void> scheduleInitialRemainderForTask(
    String id,
    BuildContext context,
    Map<String, dynamic> taskDetails,
    ToDoDataBase db,
    int index,
  ) async {
    List<Task> toDoList = db.toDoList;
    DateTime? dueDate = DateTimeUtilsHelper.parseDate(taskDetails['dueDate']);
    DateTime? dueTime = DateTimeUtilsHelper.parseTime(taskDetails['dueTime']);

    if (dueDate == null || dueTime == null) {
      logd(
        "scheduleInitialRemainderForTask: dueDate or dueTime is null, skipping.",
      );
      return;
    }

    // --- Permission check ---
    if (!await isNotificationPermissionGranted()) {
      //runs only if not granted and user needs to be prompted. If permission is permanently denied, user is directed to settings. If permission is requestable, rationale dialog is shown first, then permission is requested. If user denies at any point, function exits without scheduling. This ensures we don't spam the user with permission requests and only ask when they set a reminder for the first time.
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      final notifStatus = await Permission.notification.status;

      if (notifStatus.isPermanentlyDenied) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Notification permission denied. Enable it in Settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }

      // Denied but requestable — show rationale dialog first
      if (!context.mounted) return;
      final bool userAccepted =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder:
                (_) => AlertDialog(
                  title: const Text('Enable Reminders?'),
                  content: const Text(
                    'To remind you about this task on time, the app needs permission to send notifications.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Not Now'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!userAccepted) return;

      final bool granted = await requestNotificationPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Notification permission denied. Enable it in Settings.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }
    }

    // --- Custom user-defined reminder ---
    if (taskDetails['remainderAmount'] >= 0 &&
        taskDetails['remainderType'] != "none") {
      DateTime reminderDateTime = NotificationService.remainderDateTime(
        dueDate,
        dueTime,
        taskDetails['remainderType'],
        taskDetails['remainderAmount'],
      );

      int reminderId = id.hashCode;

      try {
        await NotificationService.sheduledTimeNotification(
          isFullScreen: false,
          showOnLockScreen: db.settings.lockScreenReminder,
          notifRingtoneUri: db.settings.notifRingtone,
          alarmRingtoneUri: db.settings.alarmRingtone,
          repeatType: taskDetails["repeatType"],
          priority: taskDetails['taskPriority'],
          id: reminderId,
          title: "Task Reminder",
          body: taskDetails['taskName'],
          year: reminderDateTime.year,
          month: reminderDateTime.month,
          day: reminderDateTime.day,
          hour: reminderDateTime.hour,
          minutes: reminderDateTime.minute,
          payload: [
            id,
            taskDetails['taskPriority'],
            DateTimeUtilsHelper.combineDateAndTime(dueDate, dueTime),
            "Task Reminder",
            taskDetails['taskName'],
            [reminderId],
          ],
        );
      } catch (e) {
        logd("Schedule error from task page => $e");
      }

      toDoList[index].notificationIds = [reminderId];
      await db.saveTaskAt(index);
    }

    // --- Priority-based interval reminders ---
    if (taskDetails['taskPriority'] == "High" ||
        taskDetails['taskPriority'] == "Medium") {
      final int hoursBeforeStart =
          taskDetails['taskPriority'] == "High" ? 2 : 1;
      final bool isHighPriority = taskDetails['taskPriority'] == "High";

      List<DateTime> reminderTimes = [];
      List<int> reminderIds = [];

      DateTime startReminder = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(
        NotificationService.remainderDateTime(
          dueDate,
          dueTime,
          'hours',
          hoursBeforeStart,
        ),
      );
      DateTime endReminder = DateTimeUtilsHelper.utcDateTimeFromUTCvalues(
        NotificationService.remainderDateTime(dueDate, dueTime, 'hours', 0),
      );

      reminderTimes.add(startReminder);
      reminderIds.add((id + startReminder.toString()).hashCode);

      while (reminderTimes.last.isBefore(endReminder)) {
        DateTime nextReminder = reminderTimes.last.add(
          const Duration(minutes: 30),
        );
        if (!nextReminder.isAfter(endReminder)) {
          reminderTimes.add(nextReminder);
          reminderIds.add((id + nextReminder.toString()).hashCode);
        } else {
          break;
        }
      }

      logd("${taskDetails['taskPriority']} reminder times: $reminderTimes");
      logd("${taskDetails['taskPriority']} reminder IDs: $reminderIds");

      bool isFullScreen = isHighPriority;

      int i = 0;

      for (DateTime reminderTime in reminderTimes) {
        if (reminderTime.isBefore(DateTime.now().toUtc())) {
          isFullScreen = false;
          continue;
        }
        try {
          await NotificationService.sheduledTimeNotification(
            isFullScreen: isFullScreen,
            showOnLockScreen: db.settings.lockScreenReminder,
            notifRingtoneUri: db.settings.notifRingtone,
            alarmRingtoneUri: db.settings.alarmRingtone,
            repeatType: taskDetails["repeatType"],
            priority: taskDetails['taskPriority'],
            id: reminderIds[i],
            title: "Task Reminder",
            body: taskDetails['taskName'],
            year: reminderTime.year,
            month: reminderTime.month,
            day: reminderTime.day,
            hour: reminderTime.hour,
            minutes: reminderTime.minute,
            payload: [
              id,
              taskDetails['taskPriority'],
              DateTimeUtilsHelper.combineDateAndTime(dueDate, dueTime),
              "Task Reminder",
              taskDetails['taskName'],
              reminderIds,
            ],
          );
        } catch (e) {
          logd("${taskDetails['taskPriority']} task schedule error => $e");
        }
        isFullScreen = false; // only first notification is fullscreen
        i++;
      }

      toDoList[index].notificationIds = reminderIds;
      await db.saveTaskAt(index);
    }
  }
}
