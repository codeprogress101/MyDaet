import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_announcements_screen.dart';

class ModeratorDashboardScreen extends StatelessWidget {
  const ModeratorDashboardScreen({super.key});

  Stream<int> _myAssignedCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return Stream<int>.value(0);

    return FirebaseFirestore.instance
        .collection("reports")
        .where("assignedToUid", isEqualTo: uid)
        .snapshots()
        .map((s) {
          final open = s.docs.where((d) {
            final status = (d.data()["status"] ?? "").toString();
            return status == "assigned" || status == "in_review" || status == "submitted";
          });
          return open.length;
        });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<int>(
          stream: _myAssignedCount(),
          builder: (context, snap) {
            final v = snap.data ?? 0;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_ind),
                title: const Text("Assigned to me (open)"),
                trailing: Text(
                  "$v",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
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
          "Use the Reports tab to update status of assigned reports.",
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
