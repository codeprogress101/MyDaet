import 'package:flutter/material.dart';
import 'role_gate.dart';
import 'splash_screen.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _doneSplash = false;

  @override
  Widget build(BuildContext context) {
    if (!_doneSplash) {
      return SplashScreen(onDone: () => setState(() => _doneSplash = true));
    }
    return const RoleGate();
  }
}
