import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeMode>(ThemeController.new);

class ThemeController extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode'; // system/light/dark

  @override
  AppThemeMode build() {
    _load();
    return AppThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key) ?? 'system';
    state = AppThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  ThemeMode get materialThemeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }
}
