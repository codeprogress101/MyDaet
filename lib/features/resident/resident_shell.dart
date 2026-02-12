import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'resident_home_screen.dart';
import 'my_reports_screen.dart';
import 'account_screen.dart';
import 'advertisements_screen.dart';
import '../dts/presentation/dts_home_screen.dart';
import '../shared/widgets/app_bottom_nav_shell.dart';

class ResidentShell extends StatefulWidget {
  const ResidentShell({super.key});

  @override
  State<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends State<ResidentShell> {
  int _index = 0;

  final _pages = const [
    ResidentHomeScreen(),
    MyReportsScreen(),
    DtsHomeScreen(showAppBar: true),
    AdvertisementsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: AppBottomNavScaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
        currentIndex: _index,
        onSelect: (v) => setState(() => _index = v),
        items: const [
          AppNavItem(
            index: 0,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
          ),
          AppNavItem(
            index: 1,
            icon: Icons.list_alt_outlined,
            selectedIcon: Icons.list_alt,
            label: 'Reports',
          ),
          AppNavItem(
            index: 2,
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder,
            label: 'Docs',
          ),
          AppNavItem(
            index: 3,
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
            label: 'Ads',
          ),
          AppNavItem(
            index: 4,
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
