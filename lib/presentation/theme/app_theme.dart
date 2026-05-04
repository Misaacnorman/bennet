import 'package:flutter/material.dart';

ThemeData bennetTheme(Brightness brightness) {
  final seed = const Color(0xFF1B5E4B);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    visualDensity: VisualDensity.standard,
  );
}
