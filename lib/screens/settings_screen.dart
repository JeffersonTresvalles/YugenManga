import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'download_queue_screen.dart';
import 'statistics_screen.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/library_settings_screen.dart';
import 'settings/reader_settings_screen.dart';
import 'settings/downloads_settings_screen.dart';
import 'settings/data_storage_settings_screen.dart';
import 'settings/about_settings_screen.dart';

/// Main settings screen serving as the hub for all settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  /// User profile data
  Map<String, String?> _userProfile = {
    'photoUrl': null,
    'displayName': 'Manga Reader',
    'email': null,
  };

  /// Image picker instance
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initSettings();
    _loadUserProfile();
  }

  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isInitialized = true;
    });
  }

  /// Loads user profile data from cache
  Future<void> _loadUserProfile() async {
    final profile = await AuthService.instance.getCachedUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
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

  /// Handles profile picture selection
  Future<void> _pickProfilePicture(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        final localPath = await AuthService.instance.saveProfilePicture(imageFile);
        
        if (localPath != null) {
          setState(() {
            _userProfile['photoUrl'] = localPath;
          });
          _showSnackBar('Profile picture updated successfully!');
        } else {
          _showSnackBar('Failed to save profile picture');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C1C2E)
              : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Change Profile Picture',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text('Gallery', style: GoogleFonts.nunito()),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickProfilePicture(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text('Camera', style: GoogleFonts.nunito()),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickProfilePicture(ImageSource.camera);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.nunito(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage(String imageUrl) {
    if (imageUrl.startsWith('/') || imageUrl.contains('profile_pictures')) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          );
        },
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Text('More',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // â”€â”€ PROFILE HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _settingsCard(isDark, children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: _userProfile['photoUrl'] != null
                              ? ClipOval(
                                  child: _buildProfileImage(_userProfile['photoUrl']!))
                              : Icon(Icons.person,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.black : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userProfile['displayName'] ?? 'Manga Reader',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_userProfile['email'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _userProfile['email']!,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // QUICK SHORTCUTS 
          _sectionLabel('SHORTCUTS'),
          _settingsCard(isDark, children: [
            _navTile(
              icon: Icons.download_done,
              iconColor: const Color(0xFF27AE60),
              title: "Download Queue",
              subtitle: "View active & pending downloads",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadQueueScreen()),
              ),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.bar_chart,
              iconColor: const Color(0xFF5DADE2),
              title: "Statistics",
              subtitle: "View your reading stats",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          //  SETTINGS SECTIONS 
          _sectionLabel('SETTINGS'),
          _settingsCard(isDark, children: [
            _navTile(
              icon: Icons.palette_outlined,
              iconColor: scheme.primary,
              title: "Appearance",
              subtitle: "Theme and colors",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen()),
              ),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.library_books,
              iconColor: const Color(0xFFFF9800),
              title: "Library",
              subtitle: "Updates, swipe",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibrarySettingsScreen()),
              ),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.chrome_reader_mode_outlined,
              iconColor: const Color(0xFF20C997),
              title: "Reader",
              subtitle: "Reading mode, display, navigation",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReaderSettingsScreen()),
              ),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.cloud_download_outlined,
              iconColor: const Color(0xFF5DADE2),
              title: "Downloads",
              subtitle: "Auto-download, ahead, location",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DownloadsSettingsScreen()),
              ),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.storage,
              iconColor: const Color(0xFF27AE60),
              title: "Data & Storage",
              subtitle: "Cache, backups, storage space",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DataStorageSettingsScreen()),
              ),
            ),
            _divider(isDark),
            _navTile(
              icon: Icons.info_outline,
              iconColor: Colors.grey,
              title: "About",
              subtitle: "Version, changelog, legal",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutSettingsScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // â”€â”€ ACCOUNT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _sectionLabel('ACCOUNT'),
          _settingsCard(isDark, children: [
            _navTile(
              icon: Icons.logout,
              iconColor: Colors.red,
              title: "Sign Out",
              subtitle: "Leave your account on this device",
              onTap: () => _showLogoutConfirmationDialog(),
            ),
          ]),

          const SizedBox(height: 32),
          Center(
            child: Text(
              "YugenManga v2.0.0",
              style: GoogleFonts.nunito(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1C1C2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Confirm Logout',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.nunito(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.nunito(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  _showSnackBar('Signed out successfully');
                } catch (e) {
                  _showSnackBar('Error signing out: $e');
                }
              },
              child: Text(
                'Logout',
                style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
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
            ? Colors.white.withOpacity(0.07)
            : Colors.black.withOpacity(0.06),
      );

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
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
                            .withOpacity(0.5))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
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
                  .withOpacity(0.5))),
      trailing: Icon(Icons.chevron_right,
          size: 18,
          color:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
      onTap: onTap,
    );
  }

  Widget _linkTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String url,
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
                  .withOpacity(0.5))),
      trailing: Icon(Icons.chevron_right,
          size: 18,
          color:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
