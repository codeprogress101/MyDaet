import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/announcements_service.dart';
import 'admin_announcement_editor_screen.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _service = AnnouncementsService();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Announcements'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        body: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filter,
                    decoration: const InputDecoration(
                      labelText: 'Filter status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'published',
                        child: Text('Published'),
                      ),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    ],
                    onChanged: (v) => setState(() => _filter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminAnnouncementEditorScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.allAnnouncementsStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs;
                if (_filter != 'all') {
                  docs = docs
                      .where((d) => (d.data()['status'] ?? '') == _filter)
                      .toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('No announcements found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final title = (data['title'] ?? 'Untitled').toString();
                    final status = (data['status'] ?? 'draft').toString();
                    final category = (data['category'] ?? 'General').toString();
                    final views = (data['views'] ?? 0) as num;
                    final meta = _metaText(data);
                    final media = data['media'] as Map<String, dynamic>?;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: border),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            media == null ? Icons.campaign : Icons.image,
                            color: accent,
                          ),
                        ),
                        title: Text(title),
                        subtitle: Text(
                          'Status: $status | $category | ${views.toInt()} views | $meta',
                        ),
                        trailing: PopupMenuButton<_AnnouncementAction>(
                          onSelected: (action) async {
                            if (action == _AnnouncementAction.edit) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminAnnouncementEditorScreen(
                                    announcementId: d.id,
                                    initialData: data,
                                  ),
                                ),
                              );
                              return;
                            }

                            if (action == _AnnouncementAction.publish) {
                              await _service.updateStatus(d.id, 'published');
                              return;
                            }

                            if (action == _AnnouncementAction.draft) {
                              await _service.updateStatus(d.id, 'draft');
                              return;
                            }

                            if (action == _AnnouncementAction.delete) {
                              await _service.deleteAnnouncement(
                                d.id,
                                mediaPath: (media?['path'] ?? '').toString(),
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _AnnouncementAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _AnnouncementAction.publish,
                              child: Text('Publish'),
                            ),
                            PopupMenuItem(
                              value: _AnnouncementAction.draft,
                              child: Text('Move to Draft'),
                            ),
                            PopupMenuItem(
                              value: _AnnouncementAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _metaText(Map<String, dynamic> data) {
    final raw = data['updatedAt'] ?? data['createdAt'];
    if (raw is Timestamp) {
      final d = raw.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return 'Updated ${d.year}-$mm-$dd $hh:$min';
    }
    return 'Updated recently';
  }
}

enum _AnnouncementAction { edit, publish, draft, delete }
