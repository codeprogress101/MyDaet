import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_audit_log_screen.dart';
import 'admin_announcements_screen.dart';
import '../../services/permissions.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, this.userContext});

  final UserContext? userContext;

  Stream<int> _count(String collection) {
    return FirebaseFirestore.instance.collection(collection).snapshots().map(
          (s) => s.size,
        );
  }

  Stream<int> _openReportsCount() {
    return FirebaseFirestore.instance
        .collection("reports")
        .where("status", whereIn: const ["submitted", "in_review", "assigned"])
        .snapshots()
        .map((s) => s.size);
  }

  Widget _statCard({
    required String label,
    required Stream<int> stream,
    required IconData icon,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final v = snap.data ?? 0;
        return Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: Text(
              "$v",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: No Scaffold here (Shell already has AppBar + BottomNav)
    final canManageUsers =
        userContext != null && Permissions.canManageUsers(userContext!);
    final auditScope = userContext != null
        ? Permissions.auditLogScope(userContext!)
        : AuditLogScope.none;
    final canViewAuditLogs = auditScope != AuditLogScope.none;
    final auditLabel =
        auditScope == AuditLogScope.office ? "Audit Logs (Office)" : "Audit Logs";

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statCard(
          label: "Reports",
          stream: _count("reports"),
          icon: Icons.receipt_long,
        ),
        if (canManageUsers)
          _statCard(
            label: "Users",
            stream: _count("users"),
            icon: Icons.people,
          ),
        _statCard(
          label: "Open Reports",
          stream: _openReportsCount(),
          icon: Icons.flag,
        ),
        const SizedBox(height: 8),
        if (canViewAuditLogs)
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(auditLabel),
              subtitle: Text(
                auditScope == AuditLogScope.office
                    ? "View office-specific admin actions."
                    : "View recent admin actions.",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminAuditLogScreen(),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text("Announcements"),
            subtitle: const Text("Create and publish updates."),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminAnnouncementsScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Tip: Use the Reports tab to assign and update statuses.",
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
