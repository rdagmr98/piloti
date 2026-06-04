import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = ref.read(authProvider);
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      final user = ref.read(authProvider).currentUser!;
      context.go(user.isAdmin ? '/admin' : '/user');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight, size: 64, color: Color(0xFF5C6BC0)),
                const SizedBox(height: 16),
                Text(
                  'Piloti',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5C6BC0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gestione voli e idoneità',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    auth.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accedi'),
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
