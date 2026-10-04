import 'package:flutter/material.dart';

class CalendarSyncProvider with ChangeNotifier {
  bool isSyncing = false;
  double progress = 0.0;

  /// When the last pull from the connected calendars finished. In-memory
  /// only: a sync runs on every launch, so it is always set soon after start.
  DateTime? lastSyncedAt;

  void startSync() {
    isSyncing = true;
    progress = 0;
    notifyListeners();
  }

  void updateProgress(double value) {
    progress = value;
    notifyListeners();
  }

  void finishSync() {
    isSyncing = false;
    progress = 1.0;
    lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  /// Hides the progress bar without waiting for the sync to finish. The sync
  /// itself keeps running in the background.
  void dismiss() {
    isSyncing = false;
    notifyListeners();
  }

  void notify() {
    notifyListeners(); // tells widgets to rebuild
  }
}
