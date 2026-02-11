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
import '../shared/widgets/app_bottom_nav_shell.dart';

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

    return tabs;
  }

  List<AppNavItem> _buildNavItems(List<_AdminTab> tabs) {
    int indexFor(String title) => tabs.indexWhere((t) => t.title == title);

    final dashboardIndex = 0;
    final reportsIndex = indexFor("Reports");
    final adsIndex = indexFor("Advertisements");
    final usersIndex = indexFor("Users");
    final officesIndex = indexFor("Offices");

    final items = <AppNavItem>[
      AppNavItem(
        index: dashboardIndex,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: "Dashboard",
      ),
      if (reportsIndex >= 0)
        AppNavItem(
          index: reportsIndex,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: "Reports",
        ),
      if (adsIndex >= 0)
        AppNavItem(
          index: adsIndex,
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
          label: "Ads",
        ),
      if (usersIndex >= 0)
        AppNavItem(
          index: usersIndex,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: "Users",
        ),
      if (officesIndex >= 0)
        AppNavItem(
          index: officesIndex,
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
          label: "Offices",
        ),
    ];

    return items;
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

        final navItems = _buildNavItems(tabs);

        return AppBottomNavScaffold(
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
                tooltip: "Account",
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountScreen(showAppBar: true),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline),
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
          currentIndex: safeIndex,
          onSelect: (v) => setState(() => _index = v),
          items: navItems,
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
