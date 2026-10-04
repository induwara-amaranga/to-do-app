import 'package:flutter/material.dart';
import 'package:to_do_app/themes/app_colors.dart';

ThemeData lightMode = ThemeData(
  colorScheme: ColorScheme.light(
    primary: const Color.fromARGB(255, 255, 179, 26),
    onPrimary: const Color.fromARGB(213, 55, 27, 0),
    secondary: const Color.fromARGB(255, 255, 239, 199),
    tertiary: const Color.fromARGB(255, 23, 162, 255),
    onTertiary: Colors.red,
    inversePrimary: Colors.grey.shade700,
    onSecondary: const Color.fromARGB(213, 55, 27, 0),
    //background: Colors.grey.shade300,
    //onBackground: Colors.black,
    surface: Colors.white,
    onSurface: Colors.black,
  ),
  extensions: const [AppColors.light],
);
