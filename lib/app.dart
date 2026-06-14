import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/user_dashboard.dart';
import 'services/gh_db_service.dart';
import 'utils/snackbar.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/user', builder: (_, __) => const UserDashboard()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
  ],
);

class PilotiApp extends ConsumerStatefulWidget {
  const PilotiApp({super.key});

  @override
  ConsumerState<PilotiApp> createState() => _PilotiAppState();
}

class _PilotiAppState extends ConsumerState<PilotiApp> {
  @override
  void initState() {
    super.initState();
    GhDbService.saveError.addListener(_onSaveError);
  }

  @override
  void dispose() {
    GhDbService.saveError.removeListener(_onSaveError);
    super.dispose();
  }

  void _onSaveError() {
    if (GhDbService.saveError.value == null) return;
    showAppError('Salvataggio non riuscito. Controlla la connessione e riprova.');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Piloti',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
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
