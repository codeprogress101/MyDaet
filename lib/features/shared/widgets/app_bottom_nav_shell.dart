import 'package:flutter/material.dart';

class AppNavItem {
  const AppNavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final int index;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

class AppBottomNavScaffold extends StatelessWidget {
  const AppBottomNavScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onSelect,
    required this.items,
    this.appBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<AppNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: _BottomNavBar(
        items: items,
        currentIndex: currentIndex,
        onSelect: onSelect,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = scheme.primary;
    final unselectedColor = scheme.onSurfaceVariant;

    final labelStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: scheme.primary.withValues(alpha: 0.12),
            labelTextStyle: MaterialStateProperty.resolveWith(
              (states) {
                final color =
                    states.contains(MaterialState.selected)
                        ? selectedColor
                        : unselectedColor;
                return labelStyle.copyWith(color: color);
              },
            ),
            iconTheme: MaterialStateProperty.resolveWith(
              (states) {
                final color =
                    states.contains(MaterialState.selected)
                        ? selectedColor
                        : unselectedColor;
                return IconThemeData(color: color, size: 22);
              },
            ),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onSelect,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: items
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon ?? item.icon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
