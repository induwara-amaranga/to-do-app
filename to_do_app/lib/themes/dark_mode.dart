import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    primary: const Color.fromARGB(255, 20, 20, 20),
    onPrimary: const Color.fromARGB(255, 122, 122, 122),
    secondary: const Color.fromARGB(255, 30, 30, 30),
    tertiary: const Color.fromARGB(255, 47, 47, 47),
    inversePrimary: Colors.grey.shade300,
    //onSecondary: Colors.white,
    //background: Colors.grey.shade800,
    //onBackground: Colors.white,
    surface: const Color.fromARGB(255, 20, 20, 20),
    //onSurface: Colors.white,
  ),
  extensions: const [AppColors.dark],
);
