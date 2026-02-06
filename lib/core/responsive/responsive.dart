import 'package:flutter/material.dart';

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
