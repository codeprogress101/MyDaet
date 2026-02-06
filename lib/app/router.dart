import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_shell.dart';

import '../features/home/home_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/updates/updates_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/account/account_screen.dart';
import '../features/account/appearance_screen.dart';
import '../features/account/notifications_screen.dart';
import '../features/account/simple_info_screen.dart';

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

      // Subpages (from Account + bell)
      GoRoute(path: '/appearance', builder: (c, s) => const AppearanceScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),

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

      // Auth placeholders
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
