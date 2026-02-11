import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../shared/report_status.dart';
import '../admin/admin_reports_screen.dart';
import 'moderator_report_detail_screen.dart';

class ModeratorReportsScreen extends StatelessWidget {
  const ModeratorReportsScreen({super.key});

  Query<Map<String, dynamic>> _queryFor(String uid) {
    return FirebaseFirestore.instance
        .collection("reports")
        .where("assignedToUid", isEqualTo: uid)
        .orderBy("createdAt", descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final q = _queryFor(uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No assigned reports."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final statusKey =
                ReportStatusHelper.normalize(data['status']?.toString());
            final statusLabel = ReportStatusHelper.pretty(statusKey);
            final statusColor = adminReportStatusColor(statusKey);
            final assignedToUid = (data['assignedToUid'] ?? '').toString().trim();
            final assignedToEmail =
                (data['assignedToEmail'] ?? '').toString().trim();
            final assignedToName =
                (data['assignedToName'] ?? '').toString().trim();
            final officeName = (data['officeName'] ?? '').toString().trim();
            final updatedAt = data['updatedAt'] as Timestamp?;
            final createdAt = data['createdAt'] as Timestamp?;
            final when = (updatedAt ?? createdAt)?.toDate();
            final timeLabel =
                when != null ? adminReportFormatTime(when) : '';

            final assigneeLabel = adminReportAssigneeLabel(
              assignedToUid: assignedToUid,
              assignedToName: assignedToName,
              assignedToEmail: assignedToEmail,
            );
            final assigneeInitial = adminReportAssigneeInitial(
              assignedToName: assignedToName,
              assignedToEmail: assignedToEmail,
            );
            final hasAssignee = assignedToUid.isNotEmpty ||
                assignedToName.isNotEmpty ||
                assignedToEmail.isNotEmpty;
            final officeLabel = adminReportOfficeShortLabel(officeName);

            final metaParts = <String>[
              if (officeLabel.isNotEmpty) officeLabel,
              assigneeLabel,
              if (timeLabel.isNotEmpty) timeLabel,
            ];

            return Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ModeratorReportDetailScreen(reportId: d.id),
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            adminReportStatusChip(
                              label: statusLabel,
                              color: statusColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              metaParts.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 14, top: 14, bottom: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasAssignee)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  statusColor.withValues(alpha: 0.15),
                              child: Text(
                                assigneeInitial,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (hasAssignee) const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
