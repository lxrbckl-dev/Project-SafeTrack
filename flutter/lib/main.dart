import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app/app_router.dart';
import 'app/herzog_theme.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/services/notification_service.dart';
import 'core/services/onboarding_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/websocket_service.dart';
import 'features/auth/data/auth_service.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/data/form_fill_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics tree for Playwright accessibility testing on web.
  // Store handle to prevent GC from disposing semantics.
  SemanticsBinding.instance.ensureSemantics();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        // NotificationService depends on the JWT from AuthService.
        // ProxyProvider propagates the token whenever AuthService changes.
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (_) => NotificationService(),
          update: (_, auth, previous) {
            final service = previous ?? NotificationService();
            service.setToken(auth.token);
            return service;
          },
        ),
        // WebSocketService — real-time event delivery from the Go backend.
        // Connects on login, pushes notification and activity events.
        // Falls back gracefully to polling if WebSocket is unavailable.
        ChangeNotifierProxyProvider2<
          AuthService,
          NotificationService,
          WebSocketService
        >(
          create: (_) => WebSocketService(),
          update: (_, auth, notifications, previous) {
            final service = previous ?? WebSocketService();
            service.setNotificationService(notifications);
            service.setToken(auth.token);
            return service;
          },
        ),
        // AppDatabase (Drift) — single instance shared across the app.
        // Used for offline incident storage and local caching.
        Provider<AppDatabase>(
          create: (_) => constructDb(),
          dispose: (_, db) => db.close(),
        ),
        // SyncService — listens for connectivity changes and syncs
        // offline incidents to the Go API when network is restored.
        // Uses ProxyProvider to receive both the database and auth token.
        ChangeNotifierProxyProvider2<AppDatabase, AuthService, SyncService>(
          create: (context) {
            final db = context.read<AppDatabase>();
            final service = SyncService(db: db);
            service.start();
            return service;
          },
          update: (_, db, auth, previous) {
            if (previous != null) {
              previous.authToken = auth.token;
              return previous;
            }
            // previous is null: build a fresh instance and start its
            // connectivity listener (mirrors the create callback).
            final service = SyncService(db: db);
            service.authToken = auth.token;
            service.start();
            return service;
          },
        ),
        // ChatRepository is stateless — a single instance is shared app-wide.
        Provider<ChatRepository>(create: (_) => ChatRepository()),
        // FormFillService holds pending AI-dispatched form fill data.
        // Form pages consume pending data on init to auto-populate controllers.
        ChangeNotifierProvider(create: (_) => FormFillService()),
        // ThemeService — persists light/dark preference to SharedPreferences.
        ChangeNotifierProvider(create: (_) => ThemeService()..loadPreference()),
        // OnboardingService — tracks whether the first-run tour has been shown.
        Provider<OnboardingService>(create: (_) => OnboardingService(prefs)),
      ],
      child: Builder(
        builder: (context) {
          return Consumer<ThemeService>(
            builder: (context, themeService, _) => MaterialApp.router(
              title: 'SafeTrack',
              theme: herzogTheme(),
              darkTheme: herzogDarkTheme(),
              themeMode: themeService.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              routerConfig: appRouter(context.read<AuthService>()),
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}
