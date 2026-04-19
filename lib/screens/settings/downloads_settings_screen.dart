import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Downloads settings screen for managing download preferences.
class DownloadsSettingsScreen extends StatefulWidget {
  const DownloadsSettingsScreen({super.key});

  @override
  State<DownloadsSettingsScreen> createState() => _DownloadsSettingsScreenState();
}

class _DownloadsSettingsScreenState extends State<DownloadsSettingsScreen> {
  late SharedPreferences _prefs;
  late bool _autoDownloadEnabled;
  late int _downloadAhead;
  late String _downloadPath;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoDownloadEnabled = _prefs.getBool('autoDownloadEnabled') ?? false;
      _downloadAhead = _prefs.getInt('downloadAhead') ?? 3;
      _downloadPath = _prefs.getString('downloadPath') ?? "Default (Internal)";
      _isInitialized = true;
    });
  }

  void _updateSetting(String key, dynamic value) {
    if (value is bool) _prefs.setBool(key, value);
    if (value is int) _prefs.setInt(key, value);
    if (value is String) _prefs.setString(key, value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickDownloadFolder() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        _executeFolderPicker();
      } else {
        _showSnackBar("Permission denied. Check settings.");
      }
    } else {
      _executeFolderPicker();
    }
  }

  Future<void> _executeFolderPicker() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      HapticFeedback.mediumImpact();
      setState(() => _downloadPath = selectedDirectory);
      _updateSetting('downloadPath', selectedDirectory);
      _showSnackBar("Download path saved!");
    }
  }

  void _showDownloadAheadDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        int selected = _downloadAhead;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Download Ahead',
                style: GoogleFonts.nunito(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [1, 3, 5, 10].map((val) {
                final isSelected = selected == val;
                return InkWell(
                  onTap: () {
                    setDialogState(() => selected = val);
                    setState(() => _downloadAhead = val);
                    _updateSetting('downloadAhead', val);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.download,
                            size: 20,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$val chapters ahead',
                            style: GoogleFonts.nunito(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Downloads',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Automatic Download
          _sectionLabel('AUTOMATIC'),
          _settingsCard(isDark, children: [
            _switchTile(
              icon: Icons.cloud_download_outlined,
              iconColor: const Color(0xFF5DADE2),
              title: "Automatic Download",
              subtitle: "Download new chapters automatically",
              value: _autoDownloadEnabled,
              onChanged: (val) {
                setState(() => _autoDownloadEnabled = val);
                _updateSetting('autoDownloadEnabled', val);
              },
            ),
          ]),

          const SizedBox(height: 16),

          // Download Ahead
          _sectionLabel('DOWNLOAD STRATEGY'),
          _settingsCard(isDark, children: [
            _optionTile(
              icon: Icons.skip_next,
              iconColor: const Color(0xFFF39C12),
              title: "Download Ahead",
              value: '$_downloadAhead chapters',
              onTap: _showDownloadAheadDialog,
            ),
          ]),

          const SizedBox(height: 16),

          // Download Location
          _sectionLabel('STORAGE'),
          _settingsCard(isDark, children: [
            _optionTile(
              icon: Icons.folder_open_outlined,
              iconColor: const Color(0xFF27AE60),
              title: "Download Location",
              value: _downloadPath == "Default (Internal)"
                  ? "Internal"
                  : _downloadPath.split('/').last,
              onTap: _pickDownloadFolder,
            ),
          ]),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Tips',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Automatic downloads use WiFi only\n'
                  '• Download ahead pre-fetches chapters\n'
                  '• Change location to save storage space',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
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

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _iconBox(icon, iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(subtitle,
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _iconBox(icon, iconColor),
      title: Text(title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 18,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)),
        ],
      ),
      onTap: onTap,
    );
  }
}
