import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'moderator_dashboard_screen.dart';
import 'moderator_reports_screen.dart';
import 'moderator_inbox_screen.dart';
import 'moderator_advertisements_screen.dart';
import '../resident/notifications_stub_screen.dart';
import '../shared/widgets/notification_bell.dart';
import '../../services/notification_service.dart';
import '../resident/account_screen.dart';
import '../shared/widgets/app_bottom_nav_shell.dart';

class ModeratorShell extends StatefulWidget {
  const ModeratorShell({super.key});

  @override
  State<ModeratorShell> createState() => _ModeratorShellState();
}

class _ModeratorShellState extends State<ModeratorShell> {
  int _index = 0;

  final _tabs = const [
    ModeratorDashboardScreen(),
    ModeratorReportsScreen(),
    ModeratorInboxScreen(),
    ModeratorAdvertisementsScreen(),
    AccountScreen(showAppBar: false),
  ];

  String _titleFor(int i) {
    switch (i) {
      case 0:
        return "Moderator Dashboard";
      case 1:
        return "Reports";
      case 2:
        return "Inbox";
      case 3:
        return "Advertisements";
      case 4:
        return "Account";
      default:
        return "Moderator";
    }
  }

  Future<void> _logout() async {
    await NotificationService.unregisterToken();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomNavScaffold(
      appBar: AppBar(
        title: Text(_titleFor(_index)),
        actions: [
          NotificationBellButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: "Logout",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      currentIndex: _index,
      onSelect: (v) => setState(() => _index = v),
      items: const [
        AppNavItem(
          index: 0,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: "Dashboard",
        ),
        AppNavItem(
          index: 1,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: "Reports",
        ),
        AppNavItem(
          index: 3,
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
          label: "Ads",
        ),
        AppNavItem(
          index: 4,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: "Account",
        ),
      ],
    );
  }
}
