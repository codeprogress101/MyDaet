import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../dts/presentation/dts_document_detail_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/timezone_utils.dart';
import 'announcements_screen.dart';
import 'report_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  void _retry() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    final user = FirebaseAuth.instance.currentUser;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: user == null
            ? const EmptyState(
                title: 'Not logged in',
                subtitle: 'Please sign in to view notifications.',
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      title: 'Unable to load notifications',
                      subtitle: '${snapshot.error}',
                      action: TextButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final isOffline = snapshot.data!.metadata.isFromCache;
                  final docs = snapshot.data!.docs
                      .where((doc) => doc.data()['read'] != true)
                      .toList();
                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No notifications yet',
                      subtitle: 'You will see updates here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length + (isOffline ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0 && isOffline) {
                        return _OfflineBanner(textTheme: textTheme);
                      }

                      final dataIndex = isOffline ? index - 1 : index;
                      final doc = docs[dataIndex];
                      final data = doc.data();
                      final title = (data['title'] ?? 'Notification')
                          .toString();
                      final body = (data['body'] ?? '').toString();
                      final type = (data['type'] ?? '').toString();
                      final reportId = (data['reportId'] ?? '')
                          .toString()
                          .trim();
                      final dtsDocId = (data['dtsDocId'] ?? '')
                          .toString()
                          .trim();
                      final announcementId = (data['announcementId'] ?? '')
                          .toString()
                          .trim();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final createdLabel = createdAt != null
                          ? _formatDateTime(createdAt.toDate())
                          : 'Just now';

                      final icon = switch (type) {
                        'announcement_published' => Icons.campaign,
                        'dts_movement' => Icons.folder_open,
                        _ => Icons.notifications,
                      };

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: border),
                        ),
                        child: ListTile(
                          leading: Icon(icon, color: accent),
                          title: Text(
                            title,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            body.isEmpty
                                ? createdLabel
                                : '$body\n$createdLabel',
                          ),
                          isThreeLine: body.isNotEmpty,
                          onTap: () async {
                            try {
                              await doc.reference.delete();
                            } catch (_) {
                              await doc.reference.set({
                                'read': true,
                              }, SetOptions(merge: true));
                            }

                            if (type == 'announcement_published' &&
                                announcementId.isNotEmpty) {
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AnnouncementDetailScreen(
                                    announcementId: announcementId,
                                  ),
                                ),
                              );
                              return;
                            }

                            if (dtsDocId.isNotEmpty) {
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DtsDocumentDetailScreen(docId: dtsDocId),
                                ),
                              );
                              return;
                            }

                            if (reportId.isNotEmpty) {
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailScreen(reportId: reportId),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  return formatManilaDateTime(dt, includeZone: true);
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E0DA)),
      ),
      child: ListTile(
        leading: const Icon(Icons.wifi_off, color: Color(0xFFE46B2C)),
        title: Text(
          'Offline',
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Showing cached notifications.'),
      ),
    );
  }
}
