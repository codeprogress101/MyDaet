import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/ads_service.dart';
import '../shared/widgets/network_video_player.dart';
import '../shared/widgets/search_field.dart';

class AdvertisementsScreen extends StatefulWidget {
  const AdvertisementsScreen({super.key});

  @override
  State<AdvertisementsScreen> createState() => _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends State<AdvertisementsScreen> {
  final _adsService = AdsService();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs.where((d) {
      final data = d.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final body = (data['body'] ?? '').toString().toLowerCase();
      final meta = (data['meta'] ?? '').toString().toLowerCase();
      return title.contains(q) || body.contains(q) || meta.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Advertisement'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _adsService.publishedAdsStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = _filterDocs(snap.data!.docs);

            if (docs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SearchField(
                    controller: _searchController,
                    hintText: 'Search advertisements...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No advertisements found.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: dark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length + 1,
              separatorBuilder: (_, i) =>
                  i == 0 ? const SizedBox(height: 16) : const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return SearchField(
                    controller: _searchController,
                    hintText: 'Search advertisements...',
                    onChanged: (v) => setState(() => _query = v),
                  );
                }

                final doc = docs[i - 1];
                final data = doc.data();
                final title = (data['title'] ?? 'Untitled').toString();
                final body = (data['body'] ?? '').toString();
                final meta = _adMetaText(data);
                final cta = (data['cta'] ?? 'View').toString();
                final ctaUrl = (data['ctaUrl'] ?? '').toString().trim();
                final media = data['media'] as Map<String, dynamic>?;
                final reactions = data['reactions'] as Map<String, dynamic>?;
                final likeCountRaw = (reactions?['like'] ?? 0) as num;
                final dislikeCountRaw = (reactions?['dislike'] ?? 0) as num;
                final likeCount = likeCountRaw < 0 ? 0 : likeCountRaw.toInt();
                final dislikeCount =
                    dislikeCountRaw < 0 ? 0 : dislikeCountRaw.toInt();

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdvertisementDetailScreen(
                            adId: doc.id,
                            data: data,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: _PostHeader(
                            title: title,
                            meta: meta,
                          ),
                        ),
                        if (body.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: Text(
                              body,
                              style: textTheme.bodyMedium?.copyWith(
                                color: dark.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        if (media != null) _MediaPreview(media: media),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: _ReactionSummary(
                            likeCount: likeCount,
                            dislikeCount: dislikeCount,
                          ),
                        ),
                        const Divider(height: 1),
                        _PostActionBar(
                          adId: doc.id,
                          adsService: _adsService,
                          ctaLabel: cta,
                          shareUrl: ctaUrl,
                          onCta: () {
                            _handleCtaTap(
                              context,
                              ctaUrl: ctaUrl,
                              fallback: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdvertisementDetailScreen(
                                      adId: doc.id,
                                      data: data,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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
    );
  }

}

String _adMetaText(Map<String, dynamic> data) {
  final meta = (data['meta'] ?? '').toString().trim();
  if (meta.isNotEmpty) return meta;
  final raw = data['createdAt'];
  if (raw is Timestamp) {
    final d = raw.toDate();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return 'Posted ${d.year}-$mm-$dd';
  }
  return 'Posted';
}

Future<void> _handleCtaTap(
  BuildContext context, {
  required String ctaUrl,
  required VoidCallback fallback,
}) async {
  final url = ctaUrl.trim();
  if (url.isEmpty) {
    fallback();
    return;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) {
    fallback();
    return;
  }

  final canLaunch = await canLaunchUrl(uri);
  if (!canLaunch) {
    fallback();
    return;
  }

  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _handleShareTap(
  BuildContext context, {
  required String shareUrl,
}) async {
  final url = shareUrl.trim();
  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No link to share.')),
    );
    return;
  }

  final shareUri = Uri.https(
    'www.facebook.com',
    '/sharer/sharer.php',
    {'u': url},
  );

  final canLaunch = await canLaunchUrl(shareUri);
  if (!context.mounted) return;
  if (!canLaunch) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open Facebook share.')),
    );
    return;
  }

  await launchUrl(
    shareUri,
    mode: LaunchMode.externalApplication,
  );
}

class AdvertisementDetailScreen extends StatelessWidget {
  const AdvertisementDetailScreen({
    super.key,
    required this.adId,
    required this.data,
  });

  final String adId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Advertisement'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance.collection('ads').doc(adId).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? this.data;
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData && data.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (data.isEmpty) {
              return const Center(child: Text('Advertisement not found.'));
            }

            final title = (data['title'] ?? 'Untitled').toString();
            final body = (data['body'] ?? '').toString();
            final meta = _adMetaText(data);
            final cta = (data['cta'] ?? 'View').toString();
            final ctaUrl = (data['ctaUrl'] ?? '').toString().trim();
            final media = data['media'] as Map<String, dynamic>?;
            final reactions = data['reactions'] as Map<String, dynamic>?;
            final likeCountRaw = (reactions?['like'] ?? 0) as num;
            final dislikeCountRaw = (reactions?['dislike'] ?? 0) as num;
            final likeCount = likeCountRaw < 0 ? 0 : likeCountRaw.toInt();
            final dislikeCount =
                dislikeCountRaw < 0 ? 0 : dislikeCountRaw.toInt();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: _PostHeader(
                          title: title,
                          meta: meta,
                        ),
                      ),
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Text(
                            body,
                            style: textTheme.bodyMedium?.copyWith(
                              color: dark.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      if (media != null)
                        _MediaPreview(
                          media: media,
                          height: 220,
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: _ReactionSummary(
                          likeCount: likeCount,
                          dislikeCount: dislikeCount,
                        ),
                      ),
                      const Divider(height: 1),
                      _PostActionBar(
                        adId: adId,
                        adsService: AdsService(),
                        ctaLabel: cta,
                        shareUrl: ctaUrl,
                        onCta: () {
                          _handleCtaTap(
                            context,
                            ctaUrl: ctaUrl,
                            fallback: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No link provided.'),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;
    final textTheme = Theme.of(context).textTheme;
    final metaText = meta.isNotEmpty ? 'Sponsored • $meta' : 'Sponsored';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: border,
          child: ClipOval(
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                metaText,
                style: textTheme.bodySmall?.copyWith(
                  color: dark.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.more_horiz, color: accent),
      ],
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({
    required this.likeCount,
    required this.dislikeCount,
  });

  final int likeCount;
  final int dislikeCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        const Icon(Icons.thumb_up, size: 16, color: accent),
        const SizedBox(width: 4),
        Text(
          '$likeCount',
          style: textTheme.bodySmall?.copyWith(
            color: dark.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.thumb_down, size: 16, color: dark.withValues(alpha: 0.45)),
        const SizedBox(width: 4),
        Text(
          '$dislikeCount',
          style: textTheme.bodySmall?.copyWith(
            color: dark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _PostActionBar extends StatelessWidget {
  const _PostActionBar({
    required this.adId,
    required this.adsService,
    required this.ctaLabel,
    required this.shareUrl,
    required this.onCta,
  });

  final String adId;
  final AdsService adsService;
  final String ctaLabel;
  final String shareUrl;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: adsService.myReactionStream(adId),
      builder: (context, snap) {
        String? type;
        if (snap.data?.data() != null) {
          type = (snap.data!.data()!['type'] ?? '').toString();
        }

        final liked = type == 'like';
        final disliked = type == 'dislike';

        return Row(
          children: [
            Expanded(
              child: _PostActionButton(
                icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: 'Like',
                color: liked ? accent : dark.withValues(alpha: 0.7),
                onTap: () => adsService.setReaction(adId, liked ? null : 'like'),
              ),
            ),
            Expanded(
              child: _PostActionButton(
                icon: disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                label: 'Dislike',
                color: disliked ? accent : dark.withValues(alpha: 0.7),
                onTap: () =>
                    adsService.setReaction(adId, disliked ? null : 'dislike'),
              ),
            ),
            Expanded(
              child: _PostActionButton(
                icon: Icons.open_in_new,
                label: ctaLabel,
                color: accent,
                onTap: onCta,
              ),
            ),
            Expanded(
              child: _PostActionButton(
                icon: Icons.share,
                label: 'Share',
                color: dark.withValues(alpha: 0.7),
                onTap: () => _handleShareTap(
                  context,
                  shareUrl: shareUrl,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(0, 44),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.media,
    this.height = 160,
  });

  final Map<String, dynamic> media;
  final double height;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    const accent = Color(0xFFE46B2C);
    final type = (media['type'] ?? '').toString();
    final url = (media['url'] ?? '').toString();
    final thumb = (media['thumbUrl'] ?? '').toString();

    if (type == 'image' && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _mediaFallback(context, height),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _mediaFallback(context, height);
          },
        ),
      );
    }

    if (type == 'video') {
      if (url.isNotEmpty) {
        return NetworkVideoPlayer(
          url: url,
          height: height,
          borderRadius: 16,
        );
      }

      if (thumb.isNotEmpty) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                thumb,
                height: height,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _mediaFallback(context, height),
              ),
            ),
            const Icon(Icons.play_circle, color: accent, size: 42),
          ],
        );
      }

      return Container(
        height: height,
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

    return _mediaFallback(context, height);
  }

  Widget _mediaFallback(BuildContext context, double height) {
    final border = Theme.of(context).dividerColor;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: const Center(child: Icon(Icons.image, color: Colors.black45)),
    );
  }
}
