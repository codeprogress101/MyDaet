import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_controller.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                RadioListTile<AppThemeMode>(
                  title: const Text('System Default'),
                  value: AppThemeMode.system,
                  groupValue: mode,
                  onChanged: (v) => controller.setMode(v!),
                ),
                RadioListTile<AppThemeMode>(
                  title: const Text('Light'),
                  value: AppThemeMode.light,
                  groupValue: mode,
                  onChanged: (v) => controller.setMode(v!),
                ),
                RadioListTile<AppThemeMode>(
                  title: const Text('Dark'),
                  value: AppThemeMode.dark,
                  groupValue: mode,
                  onChanged: (v) => controller.setMode(v!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
