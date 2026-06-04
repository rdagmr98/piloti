import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/user_dashboard.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/user', builder: (_, __) => const UserDashboard()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
  ],
);

class PilotiApp extends ConsumerWidget {
  const PilotiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Piloti',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060A14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00CFFF),
          secondary: Color(0xFF00FF88),
          surface: Color(0xFF0C1628),
        ),
      ),
      routerConfig: _router,
    );
  }
}
