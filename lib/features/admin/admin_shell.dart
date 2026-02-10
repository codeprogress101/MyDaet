import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';
import 'admin_advertisements_screen.dart';
import 'admin_offices_screen.dart';
import '../resident/notifications_stub_screen.dart';
import '../shared/widgets/notification_bell.dart';
import '../../services/notification_service.dart';
import '../../services/permissions.dart';
import '../../services/user_context_service.dart';
import '../resident/account_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  Future<void> _logout() async {
    await NotificationService.unregisterToken();
    await FirebaseAuth.instance.signOut();
  }

  List<_AdminTab> _buildTabs(UserContext userContext) {
    final tabs = <_AdminTab>[
      _AdminTab(
        page: AdminDashboardScreen(userContext: userContext),
        title: "Admin Dashboard",
        destination: const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
      ),
      _AdminTab(
        page: const AdminReportsScreen(),
        title: "Reports",
        destination: const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: "Reports",
        ),
      ),
      _AdminTab(
        page: const AdminAdvertisementsScreen(),
        title: "Advertisements",
        destination: const NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign),
          label: "Ads",
        ),
      ),
    ];

    if (Permissions.canManageUsers(userContext)) {
      tabs.add(
        _AdminTab(
          page: const AdminUsersScreen(),
          title: "Users",
          destination: const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: "Users",
          ),
        ),
      );
    }

    if (Permissions.canViewAllOffices(userContext)) {
      tabs.add(
        _AdminTab(
          page: const AdminOfficesScreen(),
          title: "Offices",
          destination: const NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: "Offices",
          ),
        ),
      );
    }

    tabs.add(
      _AdminTab(
        page: const AccountScreen(showAppBar: false),
        title: "Account",
        destination: const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: "Account",
        ),
      ),
    );

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserContext?>(
      future: _contextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        final userContext = snapshot.data;
        if (userContext == null) {
          return const Scaffold(
            body: Center(child: Text("Not logged in.")),
          );
        }
        if (!userContext.isAdmin) {
          return const Scaffold(
            body: Center(child: Text("Not authorized.")),
          );
        }

        final tabs = _buildTabs(userContext);
        final safeIndex = _index < tabs.length ? _index : 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(tabs[safeIndex].title),
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
            index: safeIndex,
            children: tabs.map((t) => t.page).toList(),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (v) => setState(() => _index = v),
            labelBehavior: tabs.length > 5
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: tabs.map((t) => t.destination).toList(),
          ),
        );
      },
    );
  }
}

class _AdminTab {
  final Widget page;
  final String title;
  final NavigationDestination destination;

  const _AdminTab({
    required this.page,
    required this.title,
    required this.destination,
  });
}
