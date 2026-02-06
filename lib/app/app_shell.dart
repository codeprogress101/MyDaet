import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/reports/report_provider.dart';


class AppShell extends ConsumerWidget {
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
      return 'MyDaet'; // Home only
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
Widget build(BuildContext context, WidgetRef ref) {
  final location = GoRouterState.of(context).uri.toString();
  final currentIndex = _indexFromLocation(location);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final unresolvedCount =
      ref.watch(reportsProvider.notifier).unresolvedCount;

  return Scaffold(
   appBar: AppBar(
  centerTitle: true,
  title: currentIndex == 0
      ? Image.asset(
          isDark
              ? 'assets/images/mydaet_logo_dark.png'
              : 'assets/images/mydaet_logo_light.png',
          height: 28,
          fit: BoxFit.contain,
        )
      : Text(
          _titleForIndex(currentIndex),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Explore',
        ),
        const NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          label: 'Updates',
        ),

        // ✅ REPORTS WITH BADGE
        NavigationDestination(
          icon: Badge(
            isLabelVisible: unresolvedCount > 0,
            label: Text(unresolvedCount.toString()),
            child: const Icon(Icons.description_outlined),
          ),
          label: 'Reports',
        ),

        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
}
}