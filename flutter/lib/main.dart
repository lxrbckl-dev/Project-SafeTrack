import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'app/app_router.dart';
import 'app/herzog_theme.dart';
import 'features/auth/data/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics tree for Playwright accessibility testing on web
  // Store handle to prevent GC from disposing semantics
  SemanticsBinding.instance.ensureSemantics();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: 'Highlander',
          theme: herzogTheme(),
          routerConfig: appRouter(context.read<AuthService>()),
        ),
      ),
    );
  }
}
