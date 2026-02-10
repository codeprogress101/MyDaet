import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/auth_gate.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final themeController = ThemeController.instance;
  await themeController.load();
  runApp(MyApp(themeController: themeController));
  NotificationService.init().catchError((error) {
    debugPrint('NotificationService.init failed: $error');
  });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.drainPending();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'MyDaet',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: NotificationService.messengerKey,
          navigatorKey: NotificationService.navigatorKey,
          themeMode: themeController.mode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const AuthGate(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    const bg = Color(0xFFFDFBFA);
    const onBg = Color(0xFF1A1E2A);
    const accent = Color(0xFFE4573D);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const bg = Color(0xFF1F1F23);
    const onBg = Color(0xFFF5F2EE);
    const accent = Color(0xFFE4573D);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: 0,
      ),
    );
  }
}
