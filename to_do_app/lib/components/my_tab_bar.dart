//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:src/models/food.dart';

class MyTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> Function() _taskCategoryTabs;
  @override
  Size get preferredSize => Size.fromHeight(60.0);

  //list of tabs

  const MyTabBar({
    super.key,
    required this.controller,
    required taskCategoryTabs,
  }) : _taskCategoryTabs = taskCategoryTabs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: TabBar(
        labelPadding: EdgeInsets.symmetric(horizontal: 12),
        //padding: EdgeInsets.zero,
        isScrollable: true,

        physics: ClampingScrollPhysics(),

        controller: controller,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.4),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 0.1,
        tabs: _taskCategoryTabs(),
      ),
    );
  }
}
