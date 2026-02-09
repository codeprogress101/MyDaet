import 'package:flutter/material.dart';
import 'package:mydaet/features/admin/admin_shell.dart';
import 'package:mydaet/features/moderator/moderator_shell.dart';

import '../services/claims_service.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/moderator/moderator_dashboard_screen.dart';

import '../features/resident/resident_shell.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final _claimsService = ClaimsService();

  bool _loading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final role = await _claimsService.getMyRole();
      if (!mounted) return;
      setState(() {
        _role = role;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _role = 'resident';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_role) {
      case 'super_admin':
      case 'admin':
        return const AdminShell();
      case 'moderator':
        return const ModeratorShell();
      default:
        return const ResidentShell();
    }
  }
}
