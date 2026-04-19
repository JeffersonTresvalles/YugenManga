import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    if (password != confirmPassword) {
      _showError("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) Navigator.pop(context); // Go back to login or home
    } catch (e) {
      if (mounted) {
        final errorMsg = e is FirebaseAuthException ? e.message : e.toString();
        _showError(errorMsg ?? "Registration failed");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: scheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: scheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, -0.6),
                radius: 1.0,
                colors: [
                  scheme.primary.withValues(alpha: 0.18),
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
                  scheme.primary.withValues(alpha: 0.04),
                  Colors.transparent,
                  scheme.primary.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Text(
                    "Join YugenManga",
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create an account to sync your library",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInputField(
                              controller: _emailController,
                              label: "Email",
                              icon: Icons.email_outlined,
                              accent: scheme.primary,
                              onSurface: scheme.onSurface,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: _passwordController,
                              label: "Password",
                              icon: Icons.lock_outline,
                              accent: scheme.primary,
                              onSurface: scheme.onSurface,
                              isPassword: true,
                              obscure: _obscurePassword,
                              onToggle: () {
                                HapticFeedback.lightImpact();
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: _confirmPasswordController,
                              label: "Confirm Password",
                              icon: Icons.lock_reset_outlined,
                              accent: scheme.primary,
                              onSurface: scheme.onSurface,
                              isPassword: true,
                              obscure: _obscureConfirmPassword,
                              onToggle: () {
                                HapticFeedback.lightImpact();
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      HapticFeedback.mediumImpact();
                                      await _handleRegister();
                                    },
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      "Create Account",
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      onChanged: (_) => HapticFeedback.lightImpact(),
      style: GoogleFonts.nunito(color: onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: onSurface.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: accent, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: accent.withValues(alpha: 0.75),
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: onSurface.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}
