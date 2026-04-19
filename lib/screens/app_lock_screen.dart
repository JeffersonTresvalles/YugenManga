import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/security_service.dart';

/// App lock screen that requires authentication to access the app.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  final TextEditingController _pinController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isAuthenticating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithPin() async {
    if (_isAuthenticating) return;

    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final authenticated = await _securityService.authenticateWithPin(pin);
      if (authenticated && mounted) {
        Navigator.of(context).pop(true); // Success
      } else {
        setState(() => _errorMessage = 'Incorrect PIN');
        _pinController.clear();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Authentication error');
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              color: scheme.primary,
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "YugenManga",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Authentication Required",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Authentication Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(22),
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
                            // PIN Input
                            TextFormField(
                              controller: _pinController,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                color: scheme.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter PIN',
                                hintStyle: GoogleFonts.nunito(
                                  color: scheme.onSurface.withValues(alpha: 0.35),
                                  fontSize: 18,
                                ),
                                filled: true,
                                fillColor: scheme.onSurface.withValues(alpha: 0.03),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: scheme.onSurface.withValues(alpha: 0.12),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: scheme.primary,
                                    width: 1.4,
                                  ),
                                ),
                                counterText: '',
                              ),
                              onFieldSubmitted: (_) => _authenticateWithPin(),
                            ),
                            const SizedBox(height: 16),

                            // Error Message
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: GoogleFonts.nunito(
                                    color: Colors.red[300],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Authenticate Button
                            FilledButton(
                              onPressed: _isAuthenticating ? null : _authenticateWithPin,
                              child: _isAuthenticating
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      "Unlock",
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
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
}