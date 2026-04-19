import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Reader settings screen for configuring reading preferences.
class ReaderSettingsScreen extends StatefulWidget {
  const ReaderSettingsScreen({super.key});

  @override
  State<ReaderSettingsScreen> createState() => _ReaderSettingsScreenState();
}

class _ReaderSettingsScreenState extends State<ReaderSettingsScreen> {
  late SharedPreferences _prefs;
  late String _readingMode;
  late String _transitionMode;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _readingMode = _prefs.getString('readMode') ?? "Vertical";
      _transitionMode = _prefs.getString('pageTransition') ?? "Fade";
      _isInitialized = true;
    });
  }

  void _updateSetting(String key, dynamic value) {
    if (value is bool) _prefs.setBool(key, value);
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
        String selected = currentValue;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
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
                    setDialogState(() => selected = opt.$1);
                    onSelect(opt.$1);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
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
        title: Text('Reader',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Reading Mode
          _sectionLabel('READING'),
          _settingsCard(isDark, children: [
            _optionTile(
              icon: Icons.chrome_reader_mode_outlined,
              iconColor: const Color(0xFF5DADE2),
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
          ]),

          const SizedBox(height: 16),

          // Display Options
          _sectionLabel('DISPLAY'),
          _settingsCard(isDark, children: [
            _optionTile(
              icon: Icons.animation,
              iconColor: const Color(0xFF20C997),
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
                  'Reading Modes',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• LTR: Left-to-right (Western style)\n'
                  '• RTL: Right-to-left (Japanese manga)\n'
                  '• Vertical: Traditional manga layout\n'
                  '• Webtoon: Vertical continuous scroll',
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
