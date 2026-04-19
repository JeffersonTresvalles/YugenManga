import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  String _emailError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();

    _loadPreferences();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (!mounted) return;
    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _signInWithEmailPassword() async {
    setState(() {
      _emailError = '';
      _passwordError = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    var hasError = false;

    if (email.isEmpty) {
      _emailError = 'Please enter your email address';
      hasError = true;
    } else if (!emailRegex.hasMatch(email)) {
      _emailError = 'Please enter a valid email address';
      hasError = true;
    }

    if (password.isEmpty) {
      _passwordError = 'Please enter your password';
      hasError = true;
    } else if (password.length < 6) {
      _passwordError = 'Password must be at least 6 characters';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _savePreferences();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (_) {
      if (mounted) {
        setState(() => _emailError = 'Network error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    if (!mounted) return;

    // Security: Use a generic message for both missing users and incorrect passwords
    if (e.code == 'user-not-found' || e.code == 'wrong-password') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid email or password',
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Sign Up',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      switch (e.code) {
        case 'invalid-email':
          _emailError = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          _emailError = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          _emailError = 'Too many failed attempts. Please try again later.';
          break;
        default:
          _emailError = 'Login failed. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardColor = theme.cardColor.withValues(alpha: 0.78);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.6),
                radius: 1.0,
                colors: [
                  scheme.primary.withValues(alpha: 0.22),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.06),
                  Colors.transparent,
                  scheme.primary.withValues(alpha: 0.14),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              color: scheme.primary,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'YugenManga',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue your manga journey',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _buildInputField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              errorText: _emailError,
                              accent: scheme.primary,
                              onSurface: scheme.onSurface,
                            ),
                            const SizedBox(height: 14),
                            _buildInputField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              errorText: _passwordError,
                              accent: scheme.primary,
                              onSurface: scheme.onSurface,
                              isPassword: true,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: scheme.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          HapticFeedback.lightImpact();
                                          setState(() => _rememberMe = value ?? false);
                                        },
                                ),
                                Text(
                                  'Remember me',
                                  style: GoogleFonts.nunito(
                                    color: scheme.onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  final messenger = ScaffoldMessenger.of(context);
                                  final email = _emailController.text.trim();
                                  if (email.isEmpty) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Enter your email first'),
                                      ),
                                    );
                                    return;
                                  }
                                  try {
                                    await AuthService.instance
                                        .sendPasswordResetEmail(email: email);
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password reset email sent.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                },
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _isLoading ? null : _signInWithEmailPassword,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      'Sign in',
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: scheme.onSurface.withValues(alpha: 0.18),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: GoogleFonts.nunito(
                                      color: scheme.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: scheme.onSurface.withValues(alpha: 0.18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      HapticFeedback.lightImpact();
                                      final messenger = ScaffoldMessenger.of(context);
                                      setState(() => _isLoading = true);
                                      try {
                                        await AuthService.instance.signInWithGoogle();
                                      } catch (e) {
                                        if (!mounted) return;
                                        final msg = e is FirebaseAuthException
                                            ? (e.message ?? 'Sign-in failed')
                                            : e.toString();
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      } finally {
                                        if (mounted) setState(() => _isLoading = false);
                                      }
                                    },
                              icon: Icon(Icons.g_mobiledata, color: scheme.primary),
                              label: Text(
                                'Continue with Google',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'New here? ',
                                  style: GoogleFonts.nunito(
                                    color: scheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Create account',
                                    style: GoogleFonts.nunito(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color accent,
    required Color onSurface,
    bool isPassword = false,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      onChanged: (_) => HapticFeedback.lightImpact(),
      style: GoogleFonts.nunito(color: onSurface, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: onSurface.withValues(alpha: 0.6)),
        floatingLabelStyle: GoogleFonts.nunito(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: accent.withValues(alpha: 0.8), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: onSurface.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        errorText: (errorText != null && errorText.isNotEmpty) ? errorText : null,
        errorStyle: GoogleFonts.nunito(
          color: Colors.redAccent.shade100,
          fontSize: 12,
        ),
      ),
    );
  }
}
