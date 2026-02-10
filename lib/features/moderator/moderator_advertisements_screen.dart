import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ads_service.dart';
import '../admin/admin_advertisement_editor_screen.dart';
import '../shared/widgets/network_video_player.dart';

class ModeratorAdvertisementsScreen extends StatefulWidget {
  const ModeratorAdvertisementsScreen({super.key});

  @override
  State<ModeratorAdvertisementsScreen> createState() =>
      _ModeratorAdvertisementsScreenState();
}

class _ModeratorAdvertisementsScreenState
    extends State<ModeratorAdvertisementsScreen> {
  final _adsService = AdsService();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
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
                              await _adsService.updateAdStatus(
                                d.id,
                                'published',
                              );
                              return;
                            }

                            if (action == _AdAction.draft) {
                              await _adsService.updateAdStatus(d.id, 'draft');
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
                              value: _AdAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ModeratorAdvertisementDetailScreen(
                                title: title,
                                data: data,
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
      ),
    );
  }
}

enum _AdAction { edit, publish, draft, delete }

class ModeratorAdvertisementDetailScreen extends StatelessWidget {
  const ModeratorAdvertisementDetailScreen({
    super.key,
    required this.title,
    required this.data,
  });

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;
    const accent = Color(0xFFE46B2C);

    final body = (data['body'] ?? '').toString();
    final meta = (data['meta'] ?? '').toString();
    final status = (data['status'] ?? 'draft').toString();
    final media = data['media'] as Map<String, dynamic>?;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Advertisement'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: $status',
                      style: textTheme.bodySmall?.copyWith(
                        color: dark.withOpacity(0.6),
                      ),
                    ),
                    if (media != null) ...[
                      const SizedBox(height: 12),
                      _MediaPreview(media: media),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: textTheme.bodyMedium?.copyWith(
                        color: dark.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      meta,
                      style: textTheme.bodySmall?.copyWith(
                        color: dark.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Moderation flow coming soon.')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Request changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media});

  final Map<String, dynamic> media;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    const accent = Color(0xFFE46B2C);
    final type = (media['type'] ?? '').toString();
    final url = (media['url'] ?? '').toString();

    if (type == 'image' && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _fallback(context);
          },
        ),
      );
    }

    if (type == 'video' && url.isNotEmpty) {
      return NetworkVideoPlayer(
        url: url,
        height: 160,
        borderRadius: 16,
      );
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: const Center(
        child: Icon(Icons.play_circle, color: accent, size: 42),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: const Center(child: Icon(Icons.image, color: Colors.black45)),
    );
  }
}
