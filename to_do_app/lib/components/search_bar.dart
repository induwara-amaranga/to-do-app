import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';

import 'package:to_do_app/themes/app_colors.dart';

class SearchBar extends StatefulWidget {
  final String searchType;

  /// How long typing must pause before the search is applied. Each applied
  /// query re-filters every tab, so doing it per keystroke is wasted work.
  final Duration debounce;

  const SearchBar({
    super.key,
    required this.searchType,
    this.debounce = const Duration(milliseconds: 250),
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  Timer? _timer;

  void _apply(String value) {
    if (!mounted) return;
    if (widget.searchType == "timetable") {
      context.read<FileSearchProvider>().setSearchQuery(value);
    } else if (widget.searchType == "task") {
      context.read<SearchingProvider>().setQuery(value);
    }
  }

  void _onChanged(String value) {
    _timer?.cancel();
    if (value.isEmpty) {
      // Clearing the box should respond at once.
      _apply(value);
      return;
    }
    _timer = Timer(widget.debounce, () => _apply(value));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: "Search...",
          hintStyle: TextStyle(fontSize: 15, color: context.appColors.muted),
          prefixIcon: Icon(
            Icons.search,
            size: 22,
            color: context.appColors.muted,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: _onChanged,
      ),
    );
  }
}
