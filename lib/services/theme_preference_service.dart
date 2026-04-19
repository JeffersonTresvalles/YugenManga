import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

/// Service for managing app theme settings including accent color preference.
class ThemePreferenceService extends ChangeNotifier {
  static final ThemePreferenceService _instance = ThemePreferenceService._internal();

  factory ThemePreferenceService() => _instance;

  ThemePreferenceService._internal();

  late SharedPreferences _prefs;
  AccentColor _accentColor = AccentColor.purple;

  AccentColor get accentColor => _accentColor;

  /// Initialize the service with SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedAccent = _prefs.getString('accentColor') ?? 'purple';
    _accentColor = AccentColorExtension.fromString(savedAccent);
  }

  /// Change the accent color and save to SharedPreferences
  Future<void> setAccentColor(AccentColor color) async {
    _accentColor = color;
    await _prefs.setString('accentColor', color.toStringValue());
    notifyListeners();
  }
}
