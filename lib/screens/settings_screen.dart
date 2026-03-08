import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import 'download_queue_screen.dart';

/// A screen that allows users to configure app-wide settings including
/// appearance, reader preferences, storage options, and app information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Reference to SharedPreferences for persisting settings across sessions.
  late SharedPreferences _prefs;

  /// Guards the build method until async settings are loaded from storage.
  bool _isInitialized = false;

  // ── Persisted Settings ───────────────────────────────────────────────────

  /// Whether the app is currently using dark mode.
  late bool _isDarkMode;

  /// The current reading direction/layout mode (e.g. "Vertical", "LTR", "RTL", "Webtoon").
  String _readingMode = "Vertical";

  /// The animation style used when turning pages (e.g. "Fade", "Slide Up", "None").
  String _transitionMode = "Fade";

  /// The file system path where downloaded manga chapters are saved.
  /// Defaults to "Default (Internal)" if the user hasn't picked a custom folder.
  String _downloadPath = "Default (Internal)";

  @override
  void initState() {
    super.initState();
    // Load saved settings as soon as the widget is inserted into the tree.
    _initSettings();
  }

  /// Asynchronously loads all persisted settings from [SharedPreferences] and
  /// triggers a rebuild once they are ready.
  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      // Fall back to the system brightness if no preference has been saved yet.
      _isDarkMode = _prefs.getBool('darkMode') ??
          (Theme.of(context).brightness == Brightness.dark);
      _readingMode = _prefs.getString('readMode') ?? "Vertical";
      _transitionMode = _prefs.getString('pageTransition') ?? "Fade";
      _downloadPath = _prefs.getString('downloadPath') ?? "Default (Internal)";
      _isInitialized = true;
    });
  }

  /// Persists a single setting to [SharedPreferences].
  ///
  /// Supports [bool] and [String] values; other types are silently ignored.
  void _updateSetting(String key, dynamic value) {
    if (value is bool) _prefs.setBool(key, value);
    if (value is String) _prefs.setString(key, value);
  }

  // ── Download Folder Picker ───────────────────────────────────────────────

  /// Requests the necessary storage permissions on Android, then opens the
  /// system folder picker. On other platforms, the picker is opened directly.
  Future<void> _pickDownloadFolder() async {
    if (Platform.isAndroid) {
      // Android requires explicit storage permission before accessing the file
      // system. We try the broader MANAGE_EXTERNAL_STORAGE first, falling back
      // to the standard STORAGE permission.
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        _executeFolderPicker();
      } else {
        _showSnackBar("Permission denied. Check settings.");
      }
    } else {
      // iOS / desktop — no additional permission needed.
      _executeFolderPicker();
    }
  }

  /// Opens the native directory-picker dialog and saves the chosen path.
  /// Provides haptic feedback and shows a confirmation snackbar on success.
  Future<void> _executeFolderPicker() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      HapticFeedback.mediumImpact();
      setState(() => _downloadPath = selectedDirectory);
      _updateSetting('downloadPath', selectedDirectory);
      _showSnackBar("Path saved!");
    }
  }

  // ── UI Helpers ───────────────────────────────────────────────────────────

  /// Displays a floating [SnackBar] with the given [message].
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while settings are being read from disk.
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Use a near-black background in dark mode and white in light mode to
      // match the card colors and avoid harsh contrast.
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Settings',
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── APPEARANCE ──────────────────────────────────────
          _sectionLabel("Appearance"),
          _settingsCard(isDark, children: [
            _switchTile(
              icon: Icons.dark_mode_outlined,
              iconColor: Colors.deepPurple,
              title: "Dark Mode",
              subtitle: _isDarkMode ? "Currently dark" : "Currently light",
              value: _isDarkMode,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _isDarkMode = val);
                _updateSetting('darkMode', val);
                // Propagate the theme change to the root MangaApp widget so
                // the entire app reflects the new brightness immediately.
                MangaApp.of(context)
                    .changeTheme(val ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ]),

          const SizedBox(height: 16),

          // ── READER ──────────────────────────────────────────
          _sectionLabel("Reader Preferences"),
          _settingsCard(isDark, children: [
            // Reading mode affects the scroll direction and page layout used
            // inside the manga viewer.
            _optionTile(
              icon: Icons.chrome_reader_mode_outlined,
              iconColor: Colors.blue,
              title: "Reading Mode",
              value: _readingMode,
              onTap: () => _showOptionsDialog(
                "Reading Mode",
                [
                  ("LTR", Icons.arrow_forward),
                  ("RTL", Icons.arrow_back),
                  ("Vertical", Icons.swap_vert),
                  ("Webtoon", Icons.view_day_outlined),
                ],
                _readingMode,
                (val) {
                  setState(() => _readingMode = val);
                  _updateSetting('readMode', val);
                },
              ),
            ),
            _divider(isDark),
            // Page transition controls the animation played between pages.
            _optionTile(
              icon: Icons.animation,
              iconColor: Colors.teal,
              title: "Page Transition",
              value: _transitionMode,
              onTap: () => _showOptionsDialog(
                "Page Transition",
                [
                  ("Fade", Icons.blur_on),
                  ("Slide Up", Icons.arrow_upward),
                  ("Slide Right", Icons.arrow_forward),
                  ("None", Icons.block),
                ],
                _transitionMode,
                (val) {
                  setState(() => _transitionMode = val);
                  _updateSetting('pageTransition', val);
                },
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── STORAGE ─────────────────────────────────────────
          _sectionLabel("Storage & Downloads"),
          _settingsCard(isDark, children: [
            // Show only the last path component when a custom folder is chosen
            // to keep the label short and readable.
            _optionTile(
              icon: Icons.folder_open_outlined,
              iconColor: Colors.orange,
              title: "Download Location",
              value: _downloadPath == "Default (Internal)"
                  ? "Default (Internal)"
                  : _downloadPath.split('/').last,
              onTap: _pickDownloadFolder,
            ),
            _divider(isDark),
            // Navigate to the download queue to inspect or manage active jobs.
            _navTile(
              icon: Icons.downloading_rounded,
              iconColor: const Color(0xFF8E8FFA),
              title: "Download Queue",
              subtitle: "View active & pending downloads",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DownloadQueueScreen())),
            ),
          ]),

          const SizedBox(height: 16),

          // ── ABOUT ────────────────────────────────────────────
          _sectionLabel("About"),
          _settingsCard(isDark, children: [
            // Opens Flutter's built-in AboutDialog with app name and version.
            _navTile(
              icon: Icons.info_outline,
              iconColor: Colors.grey,
              title: "About YugenManga",
              subtitle: "Version 1.0.0",
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'YugenManga',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.menu_book_rounded,
                    color: Colors.deepPurple, size: 40),
                children: [
                  Text(
                    "An optimized offline manga reader built for performance and user customization.",
                    style: GoogleFonts.nunito(fontSize: 13),
                  )
                ],
              ),
            ),
          ]),

          const SizedBox(height: 32),

          // Placeholder footer — can hold a build number or tagline later.
          Center(
            child: Text(
              "",
              style: GoogleFonts.nunito(
                color: scheme.onSurface.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Widget Builders ──────────────────────────────────────────────────────

  /// Renders an uppercase section heading that groups related settings tiles.
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

  /// Wraps a list of setting tiles inside a rounded card with a subtle shadow.
  ///
  /// [isDark] controls the card background colour and shadow opacity.
  Widget _settingsCard(bool isDark, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

  /// A thin horizontal rule used to separate adjacent tiles within a card.
  Widget _divider(bool isDark) => Divider(
        height: 1,
        indent: 56, // Aligns with the text content, not the leading icon.
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.06),
      );

  /// Builds a small rounded square that holds a coloured [icon].
  ///
  /// Used as the leading widget for every settings tile to provide a
  /// consistent, iOS-style visual anchor.
  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        // Tinted background uses 12 % opacity for a soft, non-distracting look.
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  /// A settings tile that renders a labelled [Switch].
  ///
  /// - [icon] / [iconColor] — leading icon box.
  /// - [title] — primary label.
  /// - [subtitle] — secondary hint that reflects the current state.
  /// - [value] / [onChanged] — current toggle state and change callback.
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

  /// A settings tile that shows the current [value] as trailing text and
  /// triggers [onTap] (typically a dialog) to let the user change it.
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
          // Display the currently selected value in a muted colour.
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  /// A settings tile that navigates to another screen or triggers an action.
  ///
  /// Unlike [_optionTile], it displays a [subtitle] rather than a current
  /// value, and does not need to reflect a persisted selection.
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  // ── Options Dialog ───────────────────────────────────────────────────────

  /// Shows a modal dialog that lets the user pick one value from [options].
  ///
  /// Parameters:
  /// - [title]        — Dialog heading.
  /// - [options]      — List of (label, icon) tuples to display as choices.
  /// - [currentValue] — The option that should appear pre-selected.
  /// - [onSelect]     — Callback invoked with the newly chosen value; the
  ///                    dialog is dismissed automatically after selection.
  void _showOptionsDialog(
    String title,
    List<(String, IconData)> options,
    String currentValue,
    Function(String) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        // Local state tracks which option is highlighted while the dialog is open.
        String selected = currentValue;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: GoogleFonts.nunito(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map(((String val, IconData ico) opt) {
                final isSelected = selected == opt.$1;
                return InkWell(
                  onTap: () {
                    // Update local dialog state, persist the choice, then close.
                    setDialogState(() => selected = opt.$1);
                    onSelect(opt.$1);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        // Icon colour changes to primary when the row is selected.
                        Icon(opt.$2,
                            size: 20,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.$1,
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
                        // Checkmark is only visible for the currently selected option.
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
}
