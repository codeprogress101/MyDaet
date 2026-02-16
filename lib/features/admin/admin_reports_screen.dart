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
  String _filter = 'all';
  bool _showArchived = false;

  static const _filters = [
    ('all', 'All'),
    ('submitted', 'Submitted'),
    ('in_review', 'In review'),
    ('assigned', 'Assigned'),
    ('in_progress', 'In progress'),
    ('resolved', 'Resolved'),
    ('rejected', 'Rejected'),
  ];

  Query<Map<String, dynamic>> _query() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final archivedDocs = docs
            .where((d) => d.data()['archived'] == true)
            .toList();
        final activeDocs = docs
            .where((d) => d.data()['archived'] != true)
            .toList();
        final scopedDocs = _showArchived ? archivedDocs : activeDocs;

        final statusCounts = <String, int>{};
        for (final item in scopedDocs) {
          final raw = (item.data()['status'] ?? '').toString();
          final key = ReportStatusHelper.normalize(raw);
          statusCounts[key] = (statusCounts[key] ?? 0) + 1;
        }

        final filteredDocs = _filter == 'all'
            ? scopedDocs
            : scopedDocs
                .where((d) {
                  final raw = (d.data()['status'] ?? '').toString();
                  return ReportStatusHelper.normalize(raw) == _filter;
                })
                .toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      if (index == _filters.length) {
                        final selected = _showArchived;
                        final count = archivedDocs.length;
                        return adminReportFilterChip(
                          context,
                          label: 'Archived ($count)',
                          selected: selected,
                          onSelected: (v) => setState(() => _showArchived = v),
                        );
                      }

                      final item = _filters[index];
                      final selected = _filter == item.$1;
                      final count = item.$1 == 'all'
                          ? scopedDocs.length
                          : (statusCounts[item.$1] ?? 0);
                      final label = '${item.$2} ($count)';
                      return adminReportFilterChip(
                        context,
                        label: label,
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = item.$1),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemCount: _filters.length + 1,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (filteredDocs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No reports found.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 12);
                      }
                      final d = filteredDocs[index ~/ 2];
                    final data = d.data();
                    final title = (data['title'] ?? 'Untitled').toString();
                    final statusKey = ReportStatusHelper.normalize(
                      data['status']?.toString(),
                    );
                    final isArchived = data['archived'] == true;
                    final statusLabel = isArchived
                        ? 'Archived'
                        : ReportStatusHelper.pretty(statusKey);
                    final statusColor = adminReportStatusColor(
                      isArchived ? 'archived' : statusKey,
                    );
                    final assignedToUid =
                        (data['assignedToUid'] ?? '').toString().trim();
                    final assignedToEmail =
                        (data['assignedToEmail'] ?? '').toString().trim();
                    final assignedToName =
                        (data['assignedToName'] ?? '').toString().trim();
                    final officeName =
                        (data['officeName'] ?? '').toString().trim();
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
                    final hasAssignee = assignedToUid.isNotEmpty ||
                        assignedToName.isNotEmpty ||
                        assignedToEmail.isNotEmpty;
                    final assigneeInitial = adminReportAssigneeInitial(
                      assignedToName: assignedToName,
                      assignedToEmail: assignedToEmail,
                    );
                    final officeLabel = adminReportOfficeShortLabel(officeName);

                    final metaParts = <String>[
                      if (officeLabel.isNotEmpty) officeLabel,
                      assigneeLabel,
                      if (timeLabel.isNotEmpty) timeLabel,
                    ];

                    final scheme = Theme.of(context).colorScheme;
                    final cardColor = scheme.surface;
                    return Material(
                      color: cardColor,
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
                              builder: (_) => AdminReportDetailScreen(
                                reportId: d.id,
                              ),
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
                                padding:
                                    const EdgeInsets.fromLTRB(14, 14, 8, 14),
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
                              padding: const EdgeInsets.only(
                                right: 14,
                                top: 14,
                                bottom: 14,
                              ),
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
                  childCount: filteredDocs.length * 2 - 1,
                ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget adminReportFilterChip(
  BuildContext context, {
  required String label,
  required bool selected,
  required ValueChanged<bool> onSelected,
}) {
  final scheme = Theme.of(context).colorScheme;
  final background = selected
      ? scheme.primary.withValues(alpha: 0.15)
      : scheme.surface;
  final borderColor =
      selected ? scheme.primary.withValues(alpha: 0.35) : scheme.outlineVariant;
  final textColor =
      selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7);

  return Material(
    color: background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: borderColor),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onSelected(!selected),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Icon(
                Icons.check,
                size: 16,
                color: textColor,
              ),
            if (selected) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget adminReportStatusChip({required String label, required Color color}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Color adminReportStatusColor(String status) {
  switch (ReportStatusHelper.normalize(status)) {
    case 'in_review':
      return const Color(0xFF3A7BD5);
    case 'assigned':
      return const Color(0xFF7E57C2);
    case 'in_progress':
      return const Color(0xFF2E7D32);
    case 'resolved':
      return const Color(0xFF2E7D32);
    case 'rejected':
      return const Color(0xFFC62828);
    case 'archived':
      return const Color(0xFF9E9E9E);
    case 'submitted':
    default:
      return const Color(0xFFE46B2C);
  }
}

String adminReportAssigneeLabel({
  required String assignedToUid,
  required String assignedToName,
  required String assignedToEmail,
}) {
  if (assignedToUid.isEmpty &&
      assignedToName.isEmpty &&
      assignedToEmail.isEmpty) {
    return 'Unassigned';
  }
  final name = assignedToName.isNotEmpty
      ? assignedToName
      : adminReportNameFromEmail(assignedToEmail);
  return name.isEmpty ? 'Assigned' : 'Assigned to $name';
}

String adminReportAssigneeInitial({
  required String assignedToName,
  required String assignedToEmail,
}) {
  final name = assignedToName.isNotEmpty
      ? assignedToName
      : adminReportNameFromEmail(assignedToEmail);
  if (name.isEmpty) return '';
  return name.trim().substring(0, 1).toUpperCase();
}

String adminReportNameFromEmail(String email) {
  if (email.isEmpty) return '';
  final local = email.split('@').first;
  if (local.isEmpty) return '';
  final parts = local.split(RegExp(r'[_\.-]+'));
  return parts
      .where((p) => p.trim().isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

String adminReportOfficeShortLabel(String name) {
  if (name.isEmpty) return '';
  final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
  if (match != null) {
    return match.group(1)?.trim() ?? name;
  }

  const stopwords = {
    'of',
    'the',
    'and',
    'office',
    'unit',
    'municipal',
    'department',
  };
  final words = name
      .replaceAll(RegExp(r'[^A-Za-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  final letters = words
      .where((w) => !stopwords.contains(w.toLowerCase()))
      .map((w) => w[0].toUpperCase())
      .join();

  if (letters.length >= 2 && letters.length <= 6) {
    return letters;
  }

  return name.length <= 20 ? name : name.substring(0, 20);
}

String adminReportFormatTime(DateTime dt) {
  int hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  if (hour == 0) hour = 12;
  if (hour > 12) hour -= 12;
  return '$hour:$minute $ampm';
}
