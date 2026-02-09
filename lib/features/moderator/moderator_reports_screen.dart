import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../shared/report_status.dart';
import 'moderator_report_detail_screen.dart';

class ModeratorReportsScreen extends StatelessWidget {
  const ModeratorReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    final q = FirebaseFirestore.instance
        .collection("reports")
        .where("assignedToUid", isEqualTo: uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = [...snap.data!.docs];
        docs.sort((a, b) {
          final aTime = _readTimestamp(a.data());
          final bTime = _readTimestamp(b.data());
          return bTime.compareTo(aTime);
        });
        if (docs.isEmpty) {
          return const Center(child: Text("No assigned reports."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data["title"] ?? "Untitled") as String;
            final status = ReportStatusHelper.pretty(
              ReportStatusHelper.normalize(data["status"] as String?),
            );

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text("Status: $status"),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ModeratorReportDetailScreen(reportId: d.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  DateTime _readTimestamp(Map<String, dynamic> data) {
    final raw = data["updatedAt"] ?? data["createdAt"];
    if (raw is Timestamp) return raw.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
