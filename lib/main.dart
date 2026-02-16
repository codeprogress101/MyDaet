import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/auth_gate.dart';
import 'services/notification_service.dart';
import 'services/observability_service.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _configureFirebaseHardening();
  final themeController = ThemeController.instance;
  await themeController.load();
  ObservabilityService.start();
  runApp(MyApp(themeController: themeController));
  NotificationService.init().catchError((error) {
    debugPrint('NotificationService.init failed: $error');
  });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.drainPending();
  });
}

Future<void> _configureFirebaseHardening() async {
  try {
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    }
  } catch (error) {
    debugPrint('FirebaseAppCheck activate failed: $error');
  }

  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
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
    const bg = Colors.white;
    const onBg = Color(0xFF1A1E2A);
    const accent = Color(0xFFE4573D);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(primary: accent, secondary: accent, surface: bg);
    final cardTheme = CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      cardTheme: cardTheme,
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
    const cardSurface = Color(0xFF2A2A30);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(primary: accent, secondary: accent, surface: cardSurface);
    final cardTheme = CardThemeData(
      color: cardSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      cardTheme: cardTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: 0,
      ),
    );
  }
}
