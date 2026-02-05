import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// --------------------
/// THEME (Appearance)
/// --------------------
enum AppThemeMode { system, light, dark }

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeMode>(ThemeController.new);

class ThemeController extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode'; // system/light/dark

  @override
  AppThemeMode build() {
    _load(); // load saved theme asynchronously
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

/// --------------------
/// ROUTING (Bottom Tabs + Subpages)
/// --------------------
final _rootNavKey = GlobalKey<NavigatorState>();
final _shellNavKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: '/home',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ExploreScreen()),
          ),
          GoRoute(
            path: '/updates',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UpdatesScreen()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/account',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AccountScreen()),
          ),
        ],
      ),

      // Subpages (opened from Account / bell)
      GoRoute(path: '/appearance', builder: (c, s) => const AppearanceScreen()),
      GoRoute(
          path: '/notifications',
          builder: (c, s) => const NotificationsScreen()),

      GoRoute(
        path: '/terms',
        builder: (c, s) => const SimpleInfoScreen(
          title: 'Terms of Service',
          body: 'Replace with official LGU terms text.',
        ),
      ),
      GoRoute(
        path: '/privacy',
        builder: (c, s) => const SimpleInfoScreen(
          title: 'Privacy Policy',
          body: 'Replace with official LGU privacy policy text.',
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (c, s) => const SimpleInfoScreen(
          title: 'Support',
          body: 'Add official Facebook page, website, hotline, email.',
        ),
      ),
      GoRoute(
        path: '/about',
        builder: (c, s) => const SimpleInfoScreen(
          title: 'About Us',
          body: 'About MyDaet and LGU Daet.',
        ),
      ),

      // Auth placeholders (we’ll wire Firebase Auth next)
      GoRoute(
        path: '/signin',
        builder: (c, s) => const SimpleInfoScreen(
          title: 'Sign In',
          body: 'Sign in screen (Firebase Auth) will go here.',
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (c, s) => const SimpleInfoScreen(
          title: 'Create Account',
          body: 'Sign up screen (Firebase Auth) will go here.',
        ),
      ),
    ],
  );
}

/// --------------------
/// APP ENTRY
/// --------------------
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme so app updates instantly when changed in Appearance
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
        colorSchemeSeed: Colors.orange, // accent orange
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange, // accent orange
        brightness: Brightness.dark,
      ),
    );
  }
}

/// --------------------
/// SHELL (Scaffold + Bottom Nav)
/// --------------------
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexFromLocation(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/updates')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/account')) return 4;
    return 0;
  }

  void _goToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.go('/updates');
        break;
      case 3:
        context.go('/reports');
        break;
      case 4:
        context.go('/account');
        break;
    }
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Explore Daet';
      case 2:
        return 'Announcements';
      case 3:
        return 'My Reports';
      case 4:
        return 'Account';
      default:
        return 'MyDaet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleForIndex(currentIndex),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _goToIndex(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}

/// --------------------
/// TAB SCREENS (Placeholders for now)
/// --------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Home (we will rebuild your MyDaet Home UI next)'),
    );
  }
}

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Explore Daet (cards list like MyNaga)'),
    );
  }
}

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Announcements / Updates list'),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('My Reports list + status tracking'),
    );
  }
}

/// --------------------
/// ACCOUNT TAB (Menu)
/// --------------------
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign in to unlock full services',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access personalized services, track your reports, and receive important updates.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/signin'),
                        child: const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.palette_outlined,
          title: 'Appearance',
          onTap: () => context.push('/appearance'),
        ),
        MenuTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () => context.push('/notifications'),
        ),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        const Text('Legal', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.gavel_outlined,
          title: 'Terms of Service',
          onTap: () => context.push('/terms'),
        ),
        MenuTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => context.push('/privacy'),
        ),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        const Text('Support', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        MenuTile(
          icon: Icons.support_agent_outlined,
          title: 'Support',
          onTap: () => context.push('/support'),
        ),
        MenuTile(
          icon: Icons.info_outline,
          title: 'About Us',
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// --------------------
/// APPEARANCE SCREEN
/// --------------------
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
          const SizedBox(height: 12),
          const Text(
            'More appearance options (font size, accessibility) will be added later.',
          ),
        ],
      ),
    );
  }
}

/// --------------------
/// NOTIFICATIONS
/// --------------------
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: const Center(child: Text('No notifications yet.')),
    );
  }
}

/// --------------------
/// SIMPLE INFO PAGES
/// --------------------
class SimpleInfoScreen extends StatelessWidget {
  final String title;
  final String body;

  const SimpleInfoScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(body),
      ),
    );
  }
}
class Responsive {
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static double maxContentWidth(BuildContext context) =>
      isWide(context) ? 720 : double.infinity;

  static int gridCount(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  static double horizontalPadding(double width) {
    if (width >= 900) return 24;
    if (width >= 600) return 20;
    return 16;
  }
}

class ConstrainedPage extends StatelessWidget {
  final Widget child;
  const ConstrainedPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(width)),
          child: child,
        ),
      ),
    );
  }
}

