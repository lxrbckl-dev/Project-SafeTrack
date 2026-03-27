import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_service.dart';
import '../features/auth/pages/dev_login_page.dart';
import '../features/poc/pages/home_page.dart';
import '../features/poc/pages/drift_test_page.dart';
import '../features/poc/pages/connectivity_test_page.dart';
import '../features/poc/pages/ollama_test_page.dart';

/// Builds the application router.
///
/// Requires an [AuthService] so the redirect logic can check login state
/// without a BuildContext dependency.
GoRouter appRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authService,
    redirect: (context, state) {
      final loggedIn = authService.isLoggedIn;
      final goingToLogin = state.matchedLocation == '/login';

      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return '/dashboard';
      return null;
    },
    routes: [
      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const DevLoginPage(),
      ),

      // Dashboard placeholder — TASK-002 will build the real shell
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const _DashboardPlaceholder(),
      ),

      // Existing POC routes (kept for dev convenience; TASK-002 will clean up)
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/drift',
        name: 'drift',
        builder: (context, state) => const DriftTestPage(),
      ),
      GoRoute(
        path: '/connectivity',
        name: 'connectivity',
        builder: (context, state) => const ConnectivityTestPage(),
      ),
      GoRoute(
        path: '/ollama',
        name: 'ollama',
        builder: (context, state) => const OllamaTestPage(),
      ),
    ],
  );
}

/// Temporary dashboard placeholder so auth redirect has somewhere to land.
/// TASK-002 will replace this with the real navigation shell.
class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DASHBOARD')),
      body: const Center(child: Text('Dashboard — coming in TASK-002')),
    );
  }
}
