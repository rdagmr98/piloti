import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_dashboard.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
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
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF5C6BC0),
          secondary: const Color(0xFF7986CB),
          surface: const Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF12121A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3A3A5E)),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
