import 'package:flutter/material.dart';
import 'package:to_do_app/models/grouping_mode.dart';

class GroupingProvider with ChangeNotifier {
  GroupingProvider({
    GroupingMode initial = GroupingMode.Default,
    this.onChanged,
  }) : _mode = initial;

  /// Called after the mode changes so it can be saved.
  final void Function(GroupingMode mode)? onChanged;

  GroupingMode _mode;

  GroupingMode get mode => _mode;

  void setMode(GroupingMode mode) {
    _mode = mode;
    onChanged?.call(mode);
    notifyListeners(); // tells widgets to rebuild
  }
}
