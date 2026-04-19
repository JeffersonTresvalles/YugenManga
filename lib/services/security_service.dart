import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  // Singleton implementation with factory to support instantiation via SecurityService()
  factory SecurityService() => instance;
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  final _auth = LocalAuthentication();

  bool _isSessionAuthenticated = false;
  bool _isAppLockEnabled = false;

  bool get isSessionAuthenticated => _isSessionAuthenticated;
  bool get isAppLockEnabled => _isAppLockEnabled;

  /// Initialises the service by loading state from secure storage.
  Future<void> init() async {
    _isAppLockEnabled = await isLockEnabled();
  }

  /// Called when the app moves to the background.
  void onAppPaused() {
    // Intentionally left blank to support "Recent Apps Only" logic.
  }

  /// Called when the app returns to the foreground.
  Future<bool> onAppResumed() async {
    if (_isAppLockEnabled && !_isSessionAuthenticated) {
      return await authenticateSession();
    }
    return true;
  }

  /// Checks if App Lock is enabled in settings
  Future<bool> isLockEnabled() async {
    String? enabled = await _storage.read(key: 'app_lock_enabled');
    return enabled == 'true';
  }

  /// Updates the App Lock state and persists the setting.
  Future<void> setAppLockEnabled(bool value) async {
    await _storage.write(key: 'app_lock_enabled', value: value.toString());
    _isAppLockEnabled = value;
  }

  /// Saves a new PIN code to secure storage.
  Future<void> setPinCode(String pin) async {
    await _storage.write(key: 'app_pin', value: pin);
  }

  /// Validates a PIN and updates session authentication state.
  Future<bool> authenticateWithPin(String pin) async {
    final storedPin = await _storage.read(key: 'app_pin');
    if (storedPin != null && storedPin == pin) {
      _isSessionAuthenticated = true;
      return true;
    }
    return false;
  }

  /// Performs the actual authentication.
  /// This should be called during the app's splash screen or main initialization.
  Future<bool> authenticateSession() async {
    if (!await isLockEnabled()) {
      _isSessionAuthenticated = true;
      return true;
    }

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock YugenManga',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows PIN/Pattern fallback
        ),
      );

      if (didAuthenticate) {
        _isSessionAuthenticated = true;
      }
      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  void lockSession() {
    _isSessionAuthenticated = false;
  }
}