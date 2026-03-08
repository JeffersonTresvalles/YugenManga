import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
// Screen imports
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/download_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const MangaApp());
}

class MangaApp extends StatefulWidget {
  const MangaApp({super.key});

  // ignore: library_private_types_in_public_api
  static _MangaAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MangaAppState>()!;

  @override
  State<MangaApp> createState() => _MangaAppState();
}

class _MangaAppState extends State<MangaApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void changeTheme(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
  }

  TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final muted =
        brightness == Brightness.dark ? Colors.white70 : Colors.black54;

    return TextTheme(
      displayLarge: GoogleFonts.nunito(
          fontSize: 32, fontWeight: FontWeight.w800, color: color),
      displayMedium: GoogleFonts.nunito(
          fontSize: 26, fontWeight: FontWeight.w800, color: color),
      displaySmall: GoogleFonts.nunito(
          fontSize: 22, fontWeight: FontWeight.w700, color: color),
      headlineLarge: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w800, color: color),
      headlineMedium: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w700, color: color),
      headlineSmall: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w700, color: color),
      titleLarge: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w700, color: color),
      titleMedium: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w600, color: color),
      titleSmall: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600, color: color),
      bodyLarge: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w500, color: color),
      bodyMedium: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w400, color: muted),
      bodySmall: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w400, color: muted),
      labelLarge: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w700, color: color),
      labelMedium: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w600, color: color),
      labelSmall: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color),
    );
  }

  NavigationBarThemeData _buildNavBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Colors.white.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white);
        }
        return IconThemeData(color: Colors.white.withValues(alpha: 0.5));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.nunito(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 11,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YugenManga',

      // --- LIGHT THEME ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepPurple,
        textTheme: _buildTextTheme(Brightness.light),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        navigationBarTheme: _buildNavBarTheme(),
      ),

      // --- DARK THEME ---
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        textTheme: _buildTextTheme(Brightness.dark),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0F0F0F),
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        navigationBarTheme: _buildNavBarTheme(),
      ),

      themeMode: _themeMode,
      home: const MainHolder(),
    );
  }
}

class MainHolder extends StatefulWidget {
  const MainHolder({super.key});

  @override
  State<MainHolder> createState() => _MainHolderState();
}

class _MainHolderState extends State<MainHolder> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          SearchScreen(key: ValueKey(brightness)),
          const FavoritesScreen(),
          const DownloadsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C0A4A), Color(0xFF2E1760)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: 'Library'),
            NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search'),
            NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favorites'),
            NavigationDestination(
                icon: Icon(Icons.download_for_offline_outlined),
                selectedIcon: Icon(Icons.download_for_offline),
                label: 'Downloads'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
