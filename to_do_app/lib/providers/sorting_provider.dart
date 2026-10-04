import 'package:flutter/material.dart';
import 'package:to_do_app/models/sorting_mode.dart';

class SortingProvider with ChangeNotifier {
  SortingProvider({
    SortingMode initial = SortingMode.createdDateDecreasing,
    this.onChanged,
  }) : _mode = initial;

  /// Called after the mode changes so it can be saved.
  final void Function(SortingMode mode)? onChanged;

  bool doSort = true;
  SortingMode _mode;

  SortingMode get mode => _mode;

  void setMode(SortingMode mode) {
    _mode = mode;
    doSort = true;
    onChanged?.call(mode);
    notifyListeners(); // tells widgets to rebuild
  }
}
