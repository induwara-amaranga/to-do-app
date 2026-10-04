import 'package:flutter/material.dart';

class ViewProvider with ChangeNotifier {
  ViewProvider({String initial = 'tileView', this.onChanged})
    : _currentView = initial;

  /// Called after the view changes so it can be saved.
  final void Function(String view)? onChanged;

  String _currentView;

  String get currentView => _currentView;

  void setView(String view) {
    _currentView = view;
    onChanged?.call(view);
    notifyListeners();
  }
}
