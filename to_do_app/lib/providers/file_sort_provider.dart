import 'package:flutter/material.dart';
import 'package:to_do_app/models/sorting_mode.dart';

class FileSortProvider with ChangeNotifier {
  FileSortProvider({
    SortingMode initial = SortingMode.createdDateDecreasing,
    this.onChanged,
  }) : _sortingMode = initial;

  /// Called after the mode changes so it can be saved.
  final void Function(SortingMode mode)? onChanged;

  SortingMode _sortingMode;
  SortingMode get sortingMode => _sortingMode;
  void setSortingMode(SortingMode mode) {
    _sortingMode = mode;
    onChanged?.call(mode);
    notifyListeners(); // tells widgets to rebuild
  }
}
