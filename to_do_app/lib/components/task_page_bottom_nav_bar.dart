import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';
//import 'package:to_do_app/pages/task_page.dart';

class TaskBottomNavBar extends StatefulWidget {
  const TaskBottomNavBar({super.key, required this.current});

  final int current;

  @override
  State<TaskBottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<TaskBottomNavBar> {
  late int current;
  @override
  void initState() {
    super.initState();
    current = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calender',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
        BottomNavigationBarItem(
          icon: Icon(Icons.insights),
          label: 'Statistics',
        ),
      ],
      currentIndex: current,

      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: kAccent,
      unselectedItemColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.45),
      selectedFontSize: 12,
      unselectedFontSize: 12,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      onTap: (index) {
        if (index == 1) {
          Navigator.pushNamed(context, '/');
        } else if (index == 0) {
          Navigator.pushNamed(context, '/calendar');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/statistics');
        }
      },
    );
  }
}
