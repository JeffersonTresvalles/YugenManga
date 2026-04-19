import 'package:flutter/material.dart';

extension ColorExtension on Color {
  /// Returns a new color with the given alpha value.
  /// The alpha value should be between 0.0 and 1.0.
  /// This is a custom extension to mimic the `withValues` method seen in the design documents.
  Color withValues({double? alpha}) {
    return withOpacity(alpha ?? 1.0);
  }
}