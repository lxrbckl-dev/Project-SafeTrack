import 'package:go_router/go_router.dart';
import '../features/poc/pages/home_page.dart';
import '../features/poc/pages/drift_test_page.dart';
import '../features/poc/pages/connectivity_test_page.dart';
import '../features/poc/pages/ollama_test_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
