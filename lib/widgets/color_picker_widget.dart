import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_theme.dart';
import '../services/theme_provider.dart';

/// A widget that displays a color picker for app accent color selection.
class ColorPickerWidget extends StatelessWidget {
  final VoidCallback? onColorChanged;

  const ColorPickerWidget({
    super.key,
    this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Get current accent color value and find the corresponding enum
    final accentColorValue = themeProvider.accentColor.value;
    final selectedColor = AccentColor.values.firstWhere(
      (c) => c.colorValue == accentColorValue,
      orElse: () => AccentColor.purple,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accent Color',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: AccentColor.values.map((color) {
              final isSelected = selectedColor == color;
              return GestureDetector(
                onTap: () async {
                  await themeProvider.setAccentColor(color);
                  onColorChanged?.call();
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.toColor(),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.toColor().withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.colorValue == 0xFFEC407A
                              ? Colors.black
                              : Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            selectedColor.displayName,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
