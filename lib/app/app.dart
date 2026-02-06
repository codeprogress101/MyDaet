import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_controller.dart';
import 'router.dart';

class MyDaetApp extends ConsumerWidget {
  const MyDaetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch so theme updates instantly after change in Appearance screen
    ref.watch(themeControllerProvider);

    final router = createRouter();
    final themeMode = ref.read(themeControllerProvider.notifier).materialThemeMode;

    return MaterialApp.router(
      title: 'MyDaet',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange, // Accent color
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange, // Accent color
        brightness: Brightness.dark,
      ),
    );
  }
}
