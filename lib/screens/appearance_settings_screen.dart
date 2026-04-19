import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../models/app_theme.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  static const List<Map<String, dynamic>> _accentColors = [
    {'name': 'Purple', 'color': AccentColor.purple},
    {'name': 'Blue', 'color': AccentColor.blue},
    {'name': 'Red', 'color': AccentColor.red},
    {'name': 'Green', 'color': AccentColor.green},
    {'name': 'Orange', 'color': AccentColor.orange},
    {'name': 'Pink', 'color': AccentColor.pink},
  ];

  @override
  Widget build(BuildContext context) {
    // Safe check for ThemeProvider to prevent Red Screen
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDark = themeProvider.isDarkMode;
    
    // If for some reason accentColor is null, provide a fallback
    final Color accentColor = themeProvider.accentColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Appearance', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Theme'),
          SwitchListTile(
            title: Text('Dark Mode', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            subtitle: Text('Apply dark theme globally', style: GoogleFonts.nunito(fontSize: 12)),
            value: themeProvider.isDarkMode,
            activeColor: accentColor,
            onChanged: (val) => themeProvider.toggleDarkMode(val),
          ),
          SwitchListTile(
            title: Text('Pure Black Mode', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            subtitle: Text('OLED optimized pitch black background', style: GoogleFonts.nunito(fontSize: 12)),
            value: themeProvider.isPureBlack,
            activeColor: accentColor,
            onChanged: themeProvider.isDarkMode ? (val) => themeProvider.togglePureBlack(val) : null,
          ),
          const SizedBox(height: 30),
          _buildSectionHeader('Accent Color'),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1,
            ),
            itemCount: _accentColors.length,
            itemBuilder: (context, index) {
              final colorData = _accentColors[index];
              final AccentColor accentColor = colorData['color'];
              final Color color = accentColor.toColor();
              final bool isSelected = themeProvider.accentColor.value == color.value;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () => themeProvider.setAccentColor(accentColor),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: [
                          if (isSelected) BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    colorData['name'],
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          _buildInfoCard(accentColor, isDark),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildInfoCard(Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Theme colors are applied to',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(Icons.radio_button_checked, 'Buttons & toggles', accent),
          _buildInfoItem(Icons.linear_scale, 'Navigation bar', accent),
          _buildInfoItem(Icons.auto_awesome, 'Icons & accents', accent),
          _buildInfoItem(Icons.text_format, 'Text highlighting', accent),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: accent.withOpacity(0.7)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}