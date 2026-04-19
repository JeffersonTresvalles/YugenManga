import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/security_service.dart';
import '../pin_setup_screen.dart';

/// Security settings screen for managing app security features.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  late SecurityService _securityService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _securityService = SecurityService();
    _initSettings();
  }

  Future<void> _initSettings() async {
    await _securityService.init();
    setState(() => _isInitialized = true);
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
        title: Text('Security',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // App Lock
          _sectionLabel('AUTHENTICATION'),
          _settingsCard(isDark, children: [
            _switchTile(
              icon: Icons.lock_outline,
              iconColor: const Color(0xFFE74C3C),
              title: "App Lock",
              subtitle: "Require PIN to open app",
              value: _securityService.isAppLockEnabled,
              onChanged: (val) async {
                if (val && !_securityService.isAppLockEnabled) {
                  // Enabling app lock - show PIN setup
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                  );

                  if (result == true) {
                    await _securityService.setAppLockEnabled(true);
                    _showSnackBar('App lock enabled');
                  }
                } else if (!val) {
                  // Disabling app lock
                  await _securityService.setAppLockEnabled(false);
                  _showSnackBar('App lock disabled');
                }
                setState(() {});
              },
            ),
          ]),

          const SizedBox(height: 16),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Features',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• App Lock: Require PIN to open the app',
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
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
}
