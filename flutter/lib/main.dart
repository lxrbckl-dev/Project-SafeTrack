import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'app/app_router.dart';
import 'app/herzog_theme.dart';
import 'core/services/notification_service.dart';
import 'features/auth/data/auth_service.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/data/form_fill_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics tree for Playwright accessibility testing on web.
  // Store handle to prevent GC from disposing semantics.
  SemanticsBinding.instance.ensureSemantics();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        // ChatRepository is stateless — a single instance is shared app-wide.
        Provider<ChatRepository>(create: (_) => ChatRepository()),
        // FormFillService holds pending AI-dispatched form fill data.
        // Form pages consume pending data on init to auto-populate controllers.
        ChangeNotifierProvider(create: (_) => FormFillService()),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: 'SafeTrack',
          theme: herzogTheme(),
          routerConfig: appRouter(context.read<AuthService>()),
        ),
      ),
    );
  }
}
