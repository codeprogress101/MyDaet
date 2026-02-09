import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../shared/report_status.dart';
import '../shared/widgets/empty_state.dart';
import 'moderator_report_detail_screen.dart';

class ModeratorInboxScreen extends StatefulWidget {
  const ModeratorInboxScreen({super.key});

  @override
  State<ModeratorInboxScreen> createState() => _ModeratorInboxScreenState();
}

class _ModeratorInboxScreenState extends State<ModeratorInboxScreen> {
  final _db = FirebaseFirestore.instance;
  final _claiming = <String, bool>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _db
        .collection("reports")
        .where("assignedToUid", isEqualTo: uid)
        .snapshots();
  }

  bool _isOpenStatus(String status) {
    final normalized = ReportStatusHelper.normalize(status);
    return normalized != "resolved" && normalized != "rejected";
  }

  DateTime _readTimestamp(Map<String, dynamic> data) {
    final raw = data["updatedAt"] ?? data["createdAt"];
    if (raw is Timestamp) return raw.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _claim(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Not logged in.")),
        );
      }
      return;
    }

    setState(() => _claiming[doc.id] = true);
    try {
      await doc.reference.set(
        {
          "assignedToUid": user.uid,
          "assignedToEmail": user.email,
          "status": "assigned",
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assigned to you.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Claim failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claiming.remove(doc.id));
      }
    }
  }

  void _openDetail(String reportId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModeratorReportDetailScreen(reportId: reportId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs
            .where((d) => _isOpenStatus((d.data()["status"] ?? "").toString()))
            .toList();

        docs.sort((a, b) {
          final aTime = _readTimestamp(a.data());
          final bTime = _readTimestamp(b.data());
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return const EmptyState(
            title: "Inbox is empty",
            subtitle: "No unassigned reports right now.",
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data["title"] ?? "Untitled").toString();
            final status = ReportStatusHelper.pretty(
              ReportStatusHelper.normalize(data["status"]?.toString()),
            );
            final createdBy =
                (data["createdByEmail"] ?? data["createdByUid"] ?? "").toString();
            final claiming = _claiming[d.id] ?? false;

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text(
                  createdBy.isEmpty
                      ? "Status: $status"
                      : "Status: $status\nFrom: $createdBy",
                ),
                onTap: () => _openDetail(d.id),
                trailing: TextButton(
                  onPressed: claiming ? null : () => _claim(d),
                  child: Text(claiming ? "Claiming..." : "Claim"),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
