import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// About settings screen with app information and changelog.
class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('About',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // App Info
          _sectionLabel(context, 'APP'),
          _settingsCard(isDark,
              children: [
            _infoTile(
              icon: Icons.info_outline,
              iconColor: const Color(0xFF5DADE2),
              title: "Version",
              value: "2.0.0",
            ),
            _divider(isDark),
            _infoTile(
              icon: Icons.calendar_today,
              iconColor: const Color(0xFF5DADE2),
              title: "Release Date",
              value: "April 2026",
            ),
            _divider(isDark),
            _infoTile(
              icon: Icons.developer_mode,
              iconColor: const Color(0xFF5DADE2),
              title: "Build",
              value: "2.0.0+1",
            ),
          ]),

          const SizedBox(height: 16),

          // More Info
          _sectionLabel(context, 'MORE'),
          _settingsCard(isDark, children: [
            _navTile(
              context,
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFF39C12),
              title: "Privacy Policy",
              subtitle: "Read our privacy policy",
              onTap: () => _showPopUp(context, "Privacy Policy", 
                "At YugenManga, we prioritize your privacy.\n\n"
                "• Account: We use Google Sign-In and Firebase to manage your library. Your data is used only for identification and sync.\n"
                "• Content: Manga data is fetched from MangaDex.\n"
                "• Storage: Downloaded chapters are stored locally in a hidden directory and are not shared with third parties.\n"
                "• Data: We do not sell or share your personal information."),
            ),
            _divider(isDark),
            _navTile(
              context,
              icon: Icons.gavel,
              iconColor: const Color(0xFFF39C12),
              title: "Terms of Service",
              subtitle: "Read our terms",
              onTap: () => _showPopUp(context, "Terms of Service", 
                "By using YugenManga, you agree to the following terms:\n\n"
                "• Content Source: This app is a 3rd-party client for MangaDex. We do not host or own any of the content provided.\n"
                "• Personal Use: The app is intended for personal, non-commercial reading only.\n"
                "• Compliance: Users are responsible for respecting copyright laws and the terms of the original content providers.\n"
                "• Disclaimer: The app is provided 'as is' without any warranties regarding service uptime or content availability."),
            ),
          ]),

          const SizedBox(height: 16),

          // Changelog
          _sectionLabel(context, 'CHANGELOG'),
          _settingsCard(isDark, children: [
            _navTile(
              context,
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF20C997),
              title: "Version History",
              subtitle: "View latest changes and fixes",
              onTap: () => _showChangelog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Team
          _sectionLabel(context, 'TEAM'),
          _settingsCard(isDark, children: [
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('Meet the Team', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                leading: _iconBox(Icons.group_outlined, Theme.of(context).colorScheme.primary),
                children: [
                  _teamTile(context, "Jefferson Tresvalles", Icons.terminal),
                  _teamTile(context, "Karl Ioseff Tivar", Icons.code),
                  _teamTile(context, "Louwie Jay Torres", Icons.architecture),
                  _teamTile(context, "Justine Hendry Zafe", Icons.brush),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Support
          _sectionLabel(context, 'SUPPORT'),
          _settingsCard(isDark, children: [
            _linkTile(
              icon: Icons.coffee,
              iconColor: Colors.brown,
              title: 'Support the Team',
              subtitle: 'Donate on Ko-fi',
              url: 'https://ko-fi.com/teamkengkoy',
            ),
          ]),

          const SizedBox(height: 16),

          // Credits
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
                  'About YugenManga',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Built by fans, for fans. YugenManga is an optimized, Tachiyomi-inspired reader designed to keep your library organized and accessible. We don't host the content; we just provide the tools to enjoy it. If the app has helped you discover a new favorite story, consider supporting our work so we can keep improving.",
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

          // Footer
          Center(
            child: Text(
              'YugenManga v2.0.0',
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

  Widget _changelogEntry(BuildContext context, String version, String date,
      List<String> features) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.new_releases,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              version,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              date,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...features
            .map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 28),
                      Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          feature,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  void _showChangelog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Changelog',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: _changelogEntry(context, 'v2.0.0', 'April 2026', [
            'Initial release',
            'Modern offline manga reader',
            'Customizable theme colors',
            'Reading statistics and heatmap',
            'Full offline support with downloads',
            'Material Design 3 interface',
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showPopUp(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1C2E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(message, style: GoogleFonts.nunito(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
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

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _iconBox(icon, iconColor),
      title: Text(title,
          style:
              GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: Text(value,
          style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF8E8FFA),
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _navTile(
    BuildContext context, {
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
          style:
              GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
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

  Widget _teamTile(BuildContext context, String name, IconData icon) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: accentColor, size: 18),
      title: Text(name, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600)),
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
              color: Colors.grey.withOpacity(0.7))),
      trailing: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
