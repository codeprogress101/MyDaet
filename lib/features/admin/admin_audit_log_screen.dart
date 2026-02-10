import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../resident/announcements_screen.dart';
import 'admin_report_detail_screen.dart';
import '../../services/permissions.dart';
import '../../services/user_context_service.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Audit Logs'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: FutureBuilder<UserContext?>(
          future: _contextFuture,
          builder: (context, contextSnap) {
            if (contextSnap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (contextSnap.hasError) {
              return Center(child: Text('Error: ${contextSnap.error}'));
            }

            final userContext = contextSnap.data;
            if (userContext == null ||
                !Permissions.canViewAuditLogs(userContext)) {
              return const Center(
                child: Text('You do not have access to audit logs.'),
              );
            }

            final scope = Permissions.auditLogScope(userContext);
            final officeId = userContext.officeId;
            if (scope == AuditLogScope.office &&
                (officeId == null || officeId.trim().isEmpty)) {
              return const Center(
                child: Text('Office not assigned for audit log access.'),
              );
            }

            Query<Map<String, dynamic>> query = FirebaseFirestore.instance
                .collection('audit_logs')
                .orderBy('createdAt', descending: true)
                .limit(100);

            if (scope == AuditLogScope.office && officeId != null) {
              query = query.where('officeId', isEqualTo: officeId);
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No audit logs yet.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final action = (data['action'] ?? '').toString();
                    final reportId = (data['reportId'] ?? '').toString();
                    final announcementId =
                        (data['announcementId'] ?? '').toString();
                    final isAnnouncement = announcementId.isNotEmpty;
                    final title = isAnnouncement
                        ? (data['announcementTitle'] ?? 'Announcement').toString()
                        : (data['reportTitle'] ?? 'Report').toString();
                    final category = isAnnouncement
                        ? (data['announcementCategory'] ?? '').toString()
                        : (data['reportCategory'] ?? '').toString();
                    final message = (data['message'] ?? '').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final when = createdAt != null
                        ? _formatDateTime(createdAt.toDate())
                        : 'Just now';

                    final actorName = (data['actorName'] ?? '').toString();
                    final actorEmail = (data['actorEmail'] ?? '').toString();
                    final actorRole = (data['actorRole'] ?? '').toString();
                    final actorUid = (data['actorUid'] ?? '').toString();
                    final actorBase = actorName.isNotEmpty
                        ? actorName
                        : actorEmail.isNotEmpty
                            ? actorEmail
                            : actorRole.isNotEmpty
                                ? actorRole.toUpperCase()
                                : 'SYSTEM';
                    final actor = actorUid.isNotEmpty
                        ? '$actorBase • $actorUid'
                        : actorBase;

                    final header = _prettyAction(
                      action,
                      title,
                      isAnnouncement: isAnnouncement,
                    );
                    final subtitle = message.isNotEmpty
                        ? message
                        : category.isNotEmpty
                            ? category
                            : isAnnouncement
                                ? 'Announcement update'
                                : 'Report update';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: border),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _actionIcon(action),
                          color: accent,
                        ),
                        title: Text(header),
                        subtitle: Text('$subtitle\n$actor • $when'),
                        isThreeLine: true,
                        trailing:
                            (reportId.isNotEmpty || announcementId.isNotEmpty)
                                ? const Icon(Icons.chevron_right)
                                : null,
                        onTap: reportId.isNotEmpty
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdminReportDetailScreen(
                                      reportId: reportId,
                                    ),
                                  ),
                                );
                              }
                            : announcementId.isNotEmpty
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AnnouncementDetailScreen(
                                          announcementId: announcementId,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _prettyAction(String action, String title, {bool isAnnouncement = false}) {
  switch (action) {
    case 'report_created':
      return 'Created: $title';
    case 'status_changed':
      return 'Status updated: $title';
    case 'assignment_changed':
      return 'Assignment updated: $title';
    case 'report_archived':
      return 'Report archived: $title';
    case 'report_restored':
      return 'Report restored: $title';
    case 'announcement_created':
      return 'Announcement created: $title';
    case 'announcement_published':
      return 'Announcement published: $title';
    case 'announcement_unpublished':
      return 'Announcement unpublished: $title';
    case 'announcement_updated':
      return 'Announcement updated: $title';
    case 'announcement_deleted':
      return 'Announcement deleted: $title';
    default:
      return isAnnouncement ? 'Announcement: $title' : title;
  }
}

IconData _actionIcon(String action) {
  switch (action) {
    case 'report_created':
      return Icons.fiber_new;
    case 'status_changed':
      return Icons.sync_alt;
    case 'assignment_changed':
      return Icons.assignment_ind;
    case 'report_archived':
      return Icons.archive_outlined;
    case 'report_restored':
      return Icons.unarchive_outlined;
    case 'announcement_created':
    case 'announcement_published':
      return Icons.campaign;
    case 'announcement_updated':
    case 'announcement_unpublished':
      return Icons.edit;
    case 'announcement_deleted':
      return Icons.delete_outline;
    default:
      return Icons.history;
  }
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final m = months[dt.month - 1];
  final day = dt.day.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$m $day, $year • $hour:$minute';
}
