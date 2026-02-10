import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../shared/report_status.dart';
import 'admin_report_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _filter = "all";
  bool _showArchived = false;

  Query<Map<String, dynamic>> _query() {
    final col = FirebaseFirestore.instance.collection("reports");
    if (_filter == "all") return col.orderBy("createdAt", descending: true);
    return col
        .where("status", isEqualTo: _filter)
        .orderBy("createdAt", descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filter,
                  decoration: const InputDecoration(
                    labelText: "Filter status",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("All")),
                    DropdownMenuItem(value: "submitted", child: Text("Submitted")),
                    DropdownMenuItem(value: "in_review", child: Text("In review")),
                    DropdownMenuItem(value: "assigned", child: Text("Assigned")),
                    DropdownMenuItem(value: "resolved", child: Text("Resolved")),
                    DropdownMenuItem(value: "rejected", child: Text("Rejected")),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? "all"),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text("Archived"),
                selected: _showArchived,
                onSelected: (v) => setState(() => _showArchived = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query().snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text("Error: ${snap.error}"));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data!.docs;
              docs = docs.where((d) {
                final archived = d.data()["archived"] == true;
                return _showArchived ? archived : !archived;
              }).toList();
              if (docs.isEmpty) {
                return const Center(child: Text("No reports found."));
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
                  final assignedTo = (data["assignedToUid"] ?? "") as String;
                  final archived = data["archived"] == true;

                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text(
                        archived ? "Status: $status • Archived" : "Status: $status",
                      ),
                      trailing: assignedTo.isEmpty
                          ? const Icon(Icons.person_off)
                          : const Icon(Icons.person),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminReportDetailScreen(
                              reportId: d.id,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
