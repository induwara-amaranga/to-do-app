import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/models/grouping_mode.dart';
import 'package:to_do_app/models/settings.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/providers/file_sort_provider.dart';
import 'package:to_do_app/providers/grouping_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/themes/theme_provider.dart';

/// The providers whose state is a user preference. Each starts from the value
/// saved in `db.settings` and writes every change straight back, so light/dark
/// mode, accent colour, and the task/timetable sort, grouping and view choices
/// all survive a restart.
List<SingleChildWidget> settingsBackedProviders(ToDoDataBase db) {
  void save(AppSettings Function(AppSettings current) change) {
    db.settings = change(db.settings);
    db.saveSettings();
  }

  return [
    ChangeNotifierProvider(
      create:
          (_) => ThemeProvider(
            accent: Color(db.settings.accentColor),
            dark: db.settings.darkMode,
            onChanged:
                (dark, accent) => save(
                  (s) => s.copyWith(
                    darkMode: dark,
                    accentColor: accent.toARGB32(),
                  ),
                ),
          ),
    ),
    ChangeNotifierProvider(
      create:
          (_) => GroupingProvider(
            initial: groupingModeFromName(db.settings.taskGroupMode),
            onChanged: (m) => save((s) => s.copyWith(taskGroupMode: m.name)),
          ),
    ),
    ChangeNotifierProvider(
      create:
          (_) => SortingProvider(
            initial: sortingModeFromName(db.settings.taskSortMode),
            onChanged: (m) => save((s) => s.copyWith(taskSortMode: m.name)),
          ),
    ),
    ChangeNotifierProvider(
      create:
          (_) => FileSortProvider(
            initial: sortingModeFromName(db.settings.timetableSortMode),
            onChanged:
                (m) => save((s) => s.copyWith(timetableSortMode: m.name)),
          ),
    ),
    ChangeNotifierProvider(
      create:
          (_) => ViewProvider(
            initial: db.settings.timetableView,
            onChanged: (v) => save((s) => s.copyWith(timetableView: v)),
          ),
    ),
  ];
}
