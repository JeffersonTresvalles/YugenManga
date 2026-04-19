import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true;
  Color _accentColor = const Color(0xFF8E8FFA);

  bool get isDarkMode => _isDarkMode;
  Color get accentColor => _accentColor;
  Color get onAccentColor => _accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? true;
    String savedAccent = AccentColor.purple.toStringValue();
    try {
      savedAccent = prefs.getString('accentColor') ?? AccentColor.purple.toStringValue();
    } catch (_) {
      // Fallback for legacy storage formats if needed.
    }
    _accentColor = AccentColorExtension.fromString(savedAccent).toColor();

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    notifyListeners();
  }

  Future<void> setAccentColor(AccentColor color) async {
    _accentColor = color.toColor();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accentColor', color.toStringValue());
    notifyListeners();
  }

  ThemeData getTheme() {
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: brightness,
    ).copyWith(primary: _accentColor);

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: _isDarkMode
          ? const Color(0xFF0A0A0A)
          : Colors.white,
      cardColor: _isDarkMode
          ? const Color(0xFF161616)
          : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: _isDarkMode
            ? const Color(0xFF0A0A0A)
            : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : Colors.black),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
        foregroundColor: onAccentColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: onAccentColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _accentColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentColor,
          side: BorderSide(color: _accentColor.withValues(alpha: 0.8)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(_accentColor),
        trackColor: WidgetStateProperty.all(_accentColor.withValues(alpha: 0.5)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _accentColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onAccentColor),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _accentColor,
        linearTrackColor: _accentColor.withValues(alpha: 0.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _accentColor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _accentColor,
        contentTextStyle: TextStyle(color: onAccentColor),
      ),
    );
  }
}