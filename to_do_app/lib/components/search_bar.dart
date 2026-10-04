import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/searching_provider.dart';

import 'package:to_do_app/themes/app_colors.dart';

class SearchBar extends StatelessWidget {
  final String searchType;
  const SearchBar({super.key, required this.searchType});

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
        onChanged: (value) {
          // Get the provider and update the query
          if (searchType == "timetable") {
            context.read<FileSearchProvider>().setSearchQuery(value);
          } else if (searchType == "task") {
            //context.read<SearchingProvider>().setTaskQuery(value);
            context.read<SearchingProvider>().setQuery(value);
          }
        },
      ),
    );
  }
}
