import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/widgets/empty_state.dart';
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
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No notifications yet',
                      subtitle: 'You will see updates here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length + (isOffline ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0 && isOffline) {
                        return _OfflineBanner(textTheme: textTheme);
                      }

                      final dataIndex = isOffline ? index - 1 : index;
                      final doc = docs[dataIndex];
                      final data = doc.data();
                      final title = (data['title'] ?? 'Notification').toString();
                      final body = (data['body'] ?? '').toString();
                      final read = data['read'] == true;
                      final type = (data['type'] ?? '').toString();
                      final reportId = (data['reportId'] ?? '').toString().trim();
                      final announcementId =
                          (data['announcementId'] ?? '').toString().trim();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final createdLabel = createdAt != null
                          ? _formatDateTime(createdAt.toDate())
                          : 'Just now';

                      final icon = type == 'announcement_published'
                          ? Icons.campaign
                          : Icons.notifications;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: border),
                        ),
                        child: ListTile(
                          leading: Icon(
                            read ? Icons.notifications_none : icon,
                            color: read ? dark.withOpacity(0.4) : accent,
                          ),
                          title: Text(
                            title,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            body.isEmpty ? createdLabel : '$body\n$createdLabel',
                          ),
                          isThreeLine: body.isNotEmpty,
                          trailing: read
                              ? null
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          onTap: () async {
                            if (!read) {
                              await doc.reference.set(
                                {'read': true},
                                SetOptions(merge: true),
                              );
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
                            if (reportId.isNotEmpty) {
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailScreen(
                                    reportId: reportId,
                                  ),
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
