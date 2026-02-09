import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ads_service.dart';
import 'admin_advertisement_editor_screen.dart';

class AdminAdvertisementsScreen extends StatefulWidget {
  const AdminAdvertisementsScreen({super.key});

  @override
  State<AdminAdvertisementsScreen> createState() =>
      _AdminAdvertisementsScreenState();
}

class _AdminAdvertisementsScreenState extends State<AdminAdvertisementsScreen> {
  final _adsService = AdsService();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filter,
                    decoration: const InputDecoration(
                      labelText: 'Filter status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'published', child: Text('Published')),
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
                        builder: (_) => const AdminAdvertisementEditorScreen(),
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
              stream: _adsService.allAdsStream(),
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
                  return const Center(child: Text('No advertisements found.'));
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
                        subtitle: Text('Status: $status'),
                        trailing: PopupMenuButton<_AdAction>(
                          onSelected: (action) async {
                            if (action == _AdAction.edit) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminAdvertisementEditorScreen(
                                    adId: d.id,
                                    initialData: data,
                                  ),
                                ),
                              );
                              return;
                            }

                            if (action == _AdAction.publish) {
                              await _adsService.updateAdStatus(d.id, 'published');
                              return;
                            }

                            if (action == _AdAction.draft) {
                              await _adsService.updateAdStatus(d.id, 'draft');
                              return;
                            }

                            if (action == _AdAction.recount) {
                              await _adsService.recountReactions(d.id);
                              return;
                            }

                            if (action == _AdAction.delete) {
                              await _adsService.deleteAd(
                                d.id,
                                mediaPath: (media?['path'] ?? '').toString(),
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _AdAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _AdAction.publish,
                              child: Text('Publish'),
                            ),
                            PopupMenuItem(
                              value: _AdAction.draft,
                              child: Text('Move to Draft'),
                            ),
                            PopupMenuItem(
                              value: _AdAction.recount,
                              child: Text('Recount reactions'),
                            ),
                            PopupMenuItem(
                              value: _AdAction.delete,
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
    );
  }
}

enum _AdAction { edit, publish, draft, recount, delete }
