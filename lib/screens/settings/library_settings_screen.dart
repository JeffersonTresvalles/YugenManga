import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/favorites_service.dart';
import '../../services/theme_provider.dart';

class LibrarySettingsScreen extends StatefulWidget {
  const LibrarySettingsScreen({super.key});

  @override
  State<LibrarySettingsScreen> createState() => _LibrarySettingsScreenState();
}

class _LibrarySettingsScreenState extends State<LibrarySettingsScreen> {
  bool _autoUpdate = true;
  String _swipeAction = 'None';
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoUpdate = prefs.getBool('library_auto_update') ?? true;
      _swipeAction = prefs.getString('library_swipe_action') ?? 'None';
      _isLoaded = true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Kept title for sub-screen context
    return Scaffold(
      appBar: AppBar(
        title: Text('Library Settings', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Other library settings can go here
          _sectionLabel('OTHER SETTINGS'),
          _settingsCard(isDark, children: [
            ListTile(
              title: Text('Updates', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              subtitle: Text('Check for new chapters automatically', 
                  style: GoogleFonts.nunito(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
              trailing: Switch(
                value: _autoUpdate, 
                onChanged: (val) {
                  setState(() => _autoUpdate = val);
                  _saveSetting('library_auto_update', val);
                },
              ),
            ),
            ListTile(
              title: Text('Swipe Actions', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              subtitle: Text('Current action: $_swipeAction', 
                  style: GoogleFonts.nunito(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSwipeActionDialog,
            ),
          ]),
        ],
      ),
    );
  }

  void _showSwipeActionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C2E) : Colors.white,
        title: Text('Library Swipe Action', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['None', 'Mark as Read', 'Delete'].map((action) => RadioListTile<String>(
            title: Text(action, style: GoogleFonts.nunito()),
            value: action,
            groupValue: _swipeAction,
            onChanged: (val) {
              if (val != null) {
                setState(() => _swipeAction = val);
                _saveSetting('library_swipe_action', val);
                Navigator.pop(context);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.nunito(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _settingsCard(bool isDark, {required List<Widget> children}) {
    return Container(
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
      child: Column(children: children),
    );
  }
}