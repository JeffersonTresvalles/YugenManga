import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  // Default to Dark Mode as it is preferred for reading applications
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    // Notify all listeners to rebuild widgets and apply the new theme globally
    notifyListeners();
  }
}
