# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project layout

The Flutter project root is **not** the repo root — it's the `to_do_app/` subdirectory:

```
<repo root>/
  to_do_app/          <- pubspec.yaml, lib/, android/, etc. live here
```

Run every command below from inside `to_do_app/`.

## Commands

```bash
flutter pub get                 # install dependencies
flutter analyze                 # primary correctness check — this repo has no
                                 # meaningful test suite, so a clean analyze is
                                 # the main signal that a change is sound
flutter devices                 # list available run targets
flutter run -d <device-id>      # run on a device/emulator
flutter build apk --debug       # Android debug build
```

There is no real test suite. `test/widget_test.dart` is the unmodified Flutter
template stub (it asserts a counter UI this app doesn't have) — don't treat
`flutter test` as a verification signal.

**Gradle memory gotcha**: `android/gradle.properties` requests
`org.gradle.jvmargs=-Xmx8G`. On a memory-constrained machine this makes the
Gradle daemon OOM-crash with "Gradle build daemon disappeared unexpectedly."
If that happens, lower `-Xmx` (and `MaxMetaspaceSize`/`ReservedCodeCacheSize`
proportionally) rather than assuming the app code is at fault.

Secrets: `lib/config/app_config.dart` holds the Supabase URL/anon key.
Override via `flutter run --dart-define=SUPABASE_ANON_KEY=<key>`; a checked-in
default is used otherwise for local dev.

## Architecture

### Data layer: Hive + hand-written adapters

Persistence is local-only via `hive`/`hive_flutter`. Despite `hive_generator`
and `build_runner` being listed in `pubspec.yaml`, **no code generation is
used** — there are no `part '*.g.dart'` files and no `@HiveType`/`@HiveField`
annotations. The `TypeAdapter` subclasses (`TaskAdapter`, `SubTaskAdapter`,
`CalendarEventAdapter`) are written by hand directly inside
`lib/models/task.dart`, `sub_task.dart`, and `calendar_event.dart`. Don't run
`build_runner` expecting it to regenerate anything.

Hive boxes (opened in `ToDoDataBase.openBoxes()`, `lib/data/database.dart`):
`tasks` (`Task`), `localCalTasks`/`googleCalTasks`/`outlookCalTasks`
(`CalendarEvent`), `meta` (settings, categories, sync config), `fileMetaBox`.

Schema migrations are tracked via `kCurrentSchemaVersion` and
`ToDoDataBase.runMigrations()`. There's also a one-time legacy path,
`_migrateLegacyMyBox()`, that imports data from a pre-typed-model Hive box
called `mybox` if one is still present on disk.

### `Task` vs `CalendarEvent` — deliberately separate models

Both live under `lib/models/` and share most fields (name, completed,
dueDate/dueTime, category, priority, repeatType, reminder settings,
subtasks, source, completedAt), but are **not** unified. The key structural
difference: `Task.remoteEventIds` is a 3-element list `[localEventId,
googleEventId, outlookEventId]`, while `CalendarEvent.remoteEventId` is a
single `String`. Conflating the two previously caused data loss across a
schema version bump — see the doc comments in `calendar_event.dart`. In
short: `Task` = user-editable to-do items (one Hive box); `CalendarEvent` =
read-only entries pulled in from calendar sync (one box per provider).

### Central state: `ToDoDataBase` + `DataProvider`, accessed two ways at once

`main.dart` creates a single global `ToDoDataBase db` and loads it at
startup. Widgets reach it through **two parallel paths that point at the
same underlying object**:

1. Passed directly as a constructor arg (`db`) to most pages/components.
2. Wrapped in `DataProvider` (a `ChangeNotifier`) registered in the top-level
   `MultiProvider` in `main.dart`, reachable via `context.watch<DataProvider>()`.

`DataProvider` exposes typed getters (`tasks`, `localEvents`, `googleEvents`,
`outlookEvents`, `categories`) that return the *same list references* as
`db.toDoList` etc. — not copies — plus a few mutation helpers (`addTask`,
`deleteTaskAt`, `reorderTasks`, `persistToDoList`, `persistAll`,
`persistCategories`). In practice, most CRUD in `task_page.dart` and
`calendar_page.dart` still mutates `db.toDoList` directly (via `setState`)
rather than going through `DataProvider`'s helpers — that's the current,
intentional-if-inconsistent pattern; match whichever style the surrounding
code in a given file already uses rather than "fixing" it in isolation.

### Calendar sync

`CordinateCalendars` (`lib/services/cordinate_calendars.dart`) is the fan-out
entry point: given a `Task`, it pushes add/update/delete to whichever of
Google/Outlook/local calendars are linked in `db.syncToCalendars`. Each
provider has its own service with parallel method shapes:

- `google_calendar_service.dart`, `outlook_calendar_service.dart`,
  `local_calendar_service.dart`
- `addOrUpdateEvent`/`addEvent`, `deleteEvent` — push a `Task`'s changes out
- `importEventsToDB` — pulls provider events in as real, editable `Task`s
- `importViewOnlyEventsToDB` — pulls provider events in as read-only
  `CalendarEvent`s into the matching box
- `syncTasksToCalendar` / `syncTasksFromCalendar(s)` — bulk push/pull

`TaskPage.importViewOnly()` drives the pull side on launch and on
pull-to-refresh.

Auth is split from sync: `AuthProvider` (`lib/providers/auth_provider.dart`)
is just a thin bag of sign-in booleans + display name for the UI to watch.
The actual OAuth flows live in `services/google_sign.dart` (Google Sign-In +
Calendar API) and `services/outlook_sign.dart` (MSAL), which call back into
`AuthProvider` to update state. `CalendarSyncProvider` is unrelated to auth —
it only tracks sync-in-progress/percentage for the UI spinner.

### Notifications

`NotificationService` (`lib/services/notification_service.dart`) builds four
fixed Android notification channels (High/Medium/Low/default priority).
Channel IDs are derived from a hash of the currently-picked ringtone URI,
because **Android notification channels are immutable once created** —
changing a channel's sound requires a new channel id, not an update to the
existing one. Full-screen (high-priority, "alarm-like") reminders use the
alarm ringtone setting; everything else uses the notification ringtone
setting. Repeating reminders use `zonedSchedule` with
`matchDateTimeComponents`. Three always-on daily notifications (morning
plan / evening review / task overview) use fixed notification IDs
(`900001`–`900003`) specifically so rescheduling is idempotent — flipping a
setting cancels-and-replaces that one notification instead of piling up
duplicates.

The native side: `android/app/.../MainActivity.kt` exposes a custom
`MethodChannel` (`com.example.to_do_app/ringtone`) wrapping Android's
`RingtoneManager` picker UI, called from `lib/components/ringtone_picker.dart`.

### Settings

`AppSettings` (`lib/models/settings.dart`) is an immutable value class
(`copyWith`/`toMap`/`fromMap`) persisted in the Hive `meta` box. Its UI is
`lib/pages/settings_page.dart` — one file containing the main screen plus all
pushed sub-screens (Notifications, Theme, Widget, Date & Time, Account,
About).

Date/time **display** formatting goes through `DateTimeUtilsHelper`'s
`display*` helpers (`displayDateNumeric`, `displayDateFriendly`,
`displayMonthYear`, `displayDayMonth`, `displayTime` in
`lib/utils/date_time_utils.dart`), which read `AppSettings.dateFormat` /
`timeFormat`. These are deliberately kept separate from `formatDate` /
`formatTime` in the same file, which are fixed-format
(`yyyy-MM-dd`/`HH:mm`) and used for **on-disk storage** — never repoint the
storage functions at a settings-driven format, or existing stored due
dates/times will misparse.

Time zone handling has a similar split: `main.dart`'s `initLocalTimeZone()`
auto-detects the device zone on every launch *unless*
`AppSettings.timeZoneManuallySet` is true, in which case it resolves the
user's picked zone label through `DateTimeUtilsHelper.locationFromTimeZoneLabel`
(a friendly-label → IANA-id lookup table, since the Settings picker shows
strings like `"UTC+5:30 (Colombo / Mumbai)"` but `package:timezone` needs
real IANA ids like `"Asia/Colombo"`).

### Navigation

Hybrid: a handful of top-level destinations are named routes declared in
`main.dart`'s `MaterialApp.routes` (`/`, `/savedTimetables`,
`/manageCategories`, `/calendarSync`, `/statistics`, `/calendar`,
`/settings`, `/filteredTasks`); everything else (edit sheets, sub-settings
screens, account pages) is pushed ad hoc via
`Navigator.push(MaterialPageRoute(...))`.
