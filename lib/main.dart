import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/download_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_helper.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseInitError;
  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } else {
        await Firebase.initializeApp();
      }

      final options = Firebase.app().options;
      if (options.apiKey.contains('REPLACE_WITH') ||
          options.projectId.contains('REPLACE_WITH') ||
          options.appId.contains('REPLACE_WITH')) {
        throw FirebaseException(
          plugin: 'firebase_core',
          code: 'invalid-firebase-config',
          message:
              'Firebase configuration contains placeholder values. Replace android/app/google-services.json or lib/firebase_options.dart with valid Firebase settings.',
        );
      }
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      firebaseInitError = e.message ?? 'Firebase initialization failed.';
    }
  } catch (e) {
    firebaseInitError = e.toString();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MangaApp(firebaseInitError: firebaseInitError),
    ),
  );
}

class MangaApp extends StatefulWidget {
  const MangaApp({super.key, this.firebaseInitError});

  final String? firebaseInitError;

  // ignore: library_private_types_in_public_api
  static _MangaAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MangaAppState>()!;

  @override
  State<MangaApp> createState() => _MangaAppState();
}

class _MangaAppState extends State<MangaApp> {
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

  NavigationBarThemeData _buildNavBarTheme(Color accentColor, bool isDark) {
    final unselectedColor = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7);

    return NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: accentColor.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: accentColor);
        }
        return IconThemeData(color: unselectedColor);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.nunito(
          color: selected ? accentColor : unselectedColor,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 11,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'YugenManga',
          theme: themeProvider.getTheme().copyWith(
                textTheme: _buildTextTheme(themeProvider.isDarkMode ? Brightness.dark : Brightness.light),
                navigationBarTheme: _buildNavBarTheme(themeProvider.accentColor, themeProvider.isDarkMode),
              ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: widget.firebaseInitError == null
              ? const AuthGate()
              : InitializationErrorScreen(message: widget.firebaseInitError!),
        );
      },
    );
  }
}

class InitializationErrorScreen extends StatelessWidget {
  const InitializationErrorScreen({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 72, color: scheme.error),
                const SizedBox(height: 20),
                Text(
                  'Firebase initialization failed',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {},
                  child: Text(
                    'Check Firebase config',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Routes unauthenticated users to [LoginScreen]; signed-in users see [MainHolder].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Security App Lock logic removed
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final scheme = Theme.of(context).colorScheme;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: scheme.primary),
            ),
          );
        }
        final user = snapshot.data;
        DatabaseHelper().setActiveUserId(user?.uid);
        if (user == null) {
          return const LoginScreen();
        }

        return const MainHolder();
      },
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;

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
        decoration: BoxDecoration(
          gradient: brightness == Brightness.dark
              ? LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.02),
                    Colors.black,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.grey.shade100],
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
                label: 'More'),
          ],
        ),
      ),
    );
  }
}
