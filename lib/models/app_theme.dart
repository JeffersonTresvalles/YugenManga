import 'package:flutter/material.dart';

enum AccentColor {
  purple('Purple', 0xFF8E8FFA),
  blue('Blue', 0xFF5DADE2),
  red('Red', 0xFFE74C3C),
  green('Green', 0xFF27AE60),
  orange('Orange', 0xFFF39C12),
  pink('Pink', 0xFFEC407A);

  const AccentColor(this.displayName, this.colorValue);

  final String displayName;
  final int colorValue;

  Color toColor() => Color(colorValue);
}

extension AccentColorExtension on AccentColor {
  static AccentColor fromString(String value) {
    try {
      return AccentColor.values.firstWhere((e) => e.name == value);
    } catch (e) {
      return AccentColor.purple; // Default to purple
    }
  }

  String toStringValue() => name;
}
