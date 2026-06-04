import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/hud_painters.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  late AnimationController _scanCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _glow;

  String _statusText = 'SISTEMA PRONTO';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _scanCtrl.dispose();
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _statusText = 'AUTENTICAZIONE IN CORSO...';
    });

    final auth = ref.read(authProvider);
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;
    if (ok) {
      setState(() => _statusText = 'ACCESSO AUTORIZZATO');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final user = ref.read(authProvider).currentUser!;
      context.go(user.isAdmin ? '/admin' : '/user');
    } else {
      setState(() {
        _isAuthenticating = false;
        _statusText = 'ACCESSO NEGATO — CREDENZIALI NON VALIDE';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_scanCtrl, _glow]),
        builder: (_, child) => Stack(
          children: [
            // Animated grid background
            Positioned.fill(
              child: CustomPaint(
                painter: HudGridPainter(_scanCtrl.value),
              ),
            ),
            child!,
          ],
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AVES Logo
                    AnimatedBuilder(
                      animation: _glow,
                      builder: (_, __) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kCyan.withValues(
                                alpha: 0.2 + 0.3 * _glow.value,
                              ),
                              blurRadius: 30 + 20 * _glow.value,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/aves_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.flight,
                              size: 64,
                              color: kCyan,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'SISTEMA PILOTI',
                      style: TextStyle(
                        color: kCyan,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        shadows: [
                          Shadow(
                            color: kCyan.withValues(alpha: 0.8),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AVIAZIONE DELL\'ESERCITO',
                      style: TextStyle(
                        color: kCyan.withValues(alpha: 0.6),
                        fontSize: 11,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Login card with corner brackets
                    CustomPaint(
                      painter: HudCornerPainter(color: kCyan, size: 16),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: kBgCard.withValues(alpha: 0.9),
                          border: Border.all(
                            color: kCyan.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _HudField(
                              controller: _userCtrl,
                              label: 'USERNAME',
                              icon: Icons.person_outline,
                              onSubmit: _login,
                            ),
                            const SizedBox(height: 16),
                            _HudField(
                              controller: _passCtrl,
                              label: 'PASSWORD',
                              icon: Icons.lock_outline,
                              obscure: _obscure,
                              toggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              onSubmit: _login,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: AnimatedBuilder(
                                animation: _glow,
                                builder: (_, __) => ElevatedButton(
                                  onPressed: _isAuthenticating ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kCyan.withValues(
                                      alpha: 0.12 + 0.06 * _glow.value,
                                    ),
                                    foregroundColor: kCyan,
                                    side: BorderSide(
                                      color: kCyan.withValues(
                                        alpha: 0.6 + 0.4 * _glow.value,
                                      ),
                                    ),
                                    shape: const RoundedRectangleBorder(),
                                    elevation: 0,
                                  ),
                                  child: _isAuthenticating
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: kCyan,
                                          ),
                                        )
                                      : const Text(
                                          'ACCEDI',
                                          style: TextStyle(
                                            letterSpacing: 4,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Status text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _glow,
                          builder: (_, __) => Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isAuthenticating ? kWarning : kGo,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isAuthenticating ? kWarning : kGo)
                                      .withValues(
                                        alpha: 0.5 + 0.5 * _glow.value,
                                      ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: kCyan.withValues(alpha: 0.5),
                            fontSize: 10,
                            letterSpacing: 2,
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
    );
  }
}

class _HudField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? toggleObscure;
  final VoidCallback onSubmit;

  const _HudField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.toggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, letterSpacing: 1),
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kCyan.withValues(alpha: 0.7), letterSpacing: 2, fontSize: 11),
        prefixIcon: Icon(icon, color: kCyan.withValues(alpha: 0.7), size: 18),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: kCyan.withValues(alpha: 0.5),
                  size: 18,
                ),
                onPressed: toggleObscure,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kCyan.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kCyan.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.zero,
        ),
        filled: true,
        fillColor: kCyan.withValues(alpha: 0.05),
      ),
    );
  }
}
