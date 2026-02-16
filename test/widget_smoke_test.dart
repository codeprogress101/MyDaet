import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydaet/features/shared/widgets/app_bottom_nav_shell.dart';

void main() {
  testWidgets('AppBottomNavScaffold renders destinations and handles taps',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppBottomNavScaffold(
          currentIndex: selected,
          onSelect: (index) => selected = index,
          items: const [
            AppNavItem(index: 0, icon: Icons.home_outlined, label: 'Home'),
            AppNavItem(index: 1, icon: Icons.receipt_long_outlined, label: 'Reports'),
            AppNavItem(index: 2, icon: Icons.person_outline, label: 'Account'),
          ],
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });
}

