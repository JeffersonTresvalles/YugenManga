import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cache_manager_service.dart';
import '../../services/backup_service.dart';

/// Data and Storage settings screen for managing app data and cache.
class DataStorageSettingsScreen extends StatefulWidget {
  const DataStorageSettingsScreen({super.key});

  @override
  State<DataStorageSettingsScreen> createState() => _DataStorageSettingsScreenState();
}

class _DataStorageSettingsScreenState extends State<DataStorageSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Data & Storage',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Cache Management
          _sectionLabel('CACHE'),
          _settingsCard(isDark, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Clear Cache",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Remove temporary files and cached manga cover images",
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showClearCacheDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Clear Cache',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Backups
          _sectionLabel('BACKUPS'),
          _settingsCard(isDark, children: [
            _navTile(
              icon: Icons.backup,
              iconColor: const Color(0xFF5DADE2),
              title: "Create Backup",
              subtitle: "Save library and settings",
              onTap: () => _createBackup(context),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.restore,
              iconColor: const Color(0xFF5DADE2),
              title: "Restore Backup",
              subtitle: "Restore from previous backup",
              onTap: () => _restoreBackup(context),
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
                  'Storage Information',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Cache stores cover images and metadata\n'
                  '• Clearing cache frees up storage space\n'
                  '• Downloads are stored in a separate folder\n'
                  '• Backups include library and reading history',
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

  void _showClearCacheDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache?',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This will remove temporarily cached files. Manga covers will be re-downloaded on next view.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await CacheManagerService.instance.clearCache();
                // ignore: use_build_context_synchronously
                _showSnackBar(context, 'Cache cleared successfully');
              } catch (e) {
                // ignore: use_build_context_synchronously
                _showSnackBar(context, 'Failed to clear cache');
              }
            },
            child: Text(
              'Clear',
              style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _createBackup(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Creating Backup...',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we create your backup.'),
          ],
        ),
      ),
    );

    try {
      final backupPath = await BackupService().createBackup();
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // Close loading dialog

      if (backupPath != null) {
        // ignore: use_build_context_synchronously
        _showSnackBar(context, 'Backup created successfully');
      } else {
        // ignore: use_build_context_synchronously
        _showSnackBar(context, 'Failed to create backup');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // Close loading dialog
      // ignore: use_build_context_synchronously
      _showSnackBar(context, 'Error creating backup: ${e.toString()}');
    }
  }

  void _restoreBackup(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restore Backup',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This will replace your current library and settings with data from the backup file. Are you sure you want to continue?',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Restore',
              style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (result != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restoring Backup...',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we restore your data.'),
          ],
        ),
      ),
    );

    try {
      final success = await BackupService().restoreBackup();
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // ignore: use_build_context_synchronously
        _showSnackBar(context, 'Backup restored successfully');
      } else {
        // ignore: use_build_context_synchronously
        _showSnackBar(context, 'Failed to restore backup');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // Close loading dialog
      // ignore: use_build_context_synchronously
      _showSnackBar(context, 'Error restoring backup: ${e.toString()}');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _divider(bool isDark) => Divider(
        height: 1,
        indent: 56,
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.06),
      );

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

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _iconBox(icon, iconColor),
      title: Text(title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle,
          style: GoogleFonts.nunito(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5))),
      trailing: Icon(Icons.chevron_right,
          size: 18,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}
