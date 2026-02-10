import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/announcements_service.dart';
import '../shared/widgets/search_field.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _service = AnnouncementsService();
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  static const _categories = [
    'All',
    'General',
    'Advisory',
    'Event',
    'Notice',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _query = initial;
      _searchController.text = initial;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _query.trim().toLowerCase();
    return docs.where((d) {
      final data = d.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final body = (data['body'] ?? '').toString().toLowerCase();
      final meta = (data['meta'] ?? '').toString().toLowerCase();
      final category = _categoryForData(data).toLowerCase();

      final matchesQuery = q.isEmpty ||
          title.contains(q) ||
          body.contains(q) ||
          meta.contains(q) ||
          category.contains(q);
      if (!matchesQuery) return false;

      if (_category != 'All' && category != _category.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

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
          title: const Text('Announcements'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.publishedAnnouncementsStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.myReadsStream(),
              builder: (context, readsSnap) {
                final readIds = <String>{};
                if (readsSnap.hasData) {
                  for (final d in readsSnap.data!.docs) {
                    readIds.add(d.id);
                  }
                }

                final filteredDocs = _filterDocs(docs);

                final filters = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchField(
                      controller: _searchController,
                      hintText: 'Search announcements...',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final label = _categories[index];
                          final selected = _category == label;
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _category = label);
                            },
                            selectedColor: accent.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: selected ? accent : dark.withValues(alpha: 0.7),
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: selected
                                    ? accent.withValues(alpha: 0.4)
                                    : border,
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _categories.length,
                      ),
                    ),
                  ],
                );

                if (filteredDocs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      filters,
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No announcements found.',
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
                  itemCount: filteredDocs.length + 1,
                  separatorBuilder: (_, i) =>
                      i == 0 ? const SizedBox(height: 16) : const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) return filters;

                    final doc = filteredDocs[i - 1];
                    final data = doc.data();
                    final title = (data['title'] ?? 'Untitled').toString();
                    final body = (data['body'] ?? '').toString();
                    final meta = _metaText(data);
                    final category = _categoryForData(data);
                    final media = data['media'] as Map<String, dynamic>?;
                    final mediaUrl = (media?['url'] ?? '').toString();
                    final isNew = user != null && !readIds.contains(doc.id);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _service.markRead(doc.id);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AnnouncementDetailScreen(
                                announcementId: doc.id,
                                data: data,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AnnouncementThumb(url: mediaUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: dark,
                                            ),
                                          ),
                                        ),
                                        if (isNew) const _NewBadge(),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: dark.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _CategoryPill(label: category),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            meta,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall?.copyWith(
                                              color: dark.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

  String _metaText(Map<String, dynamic> data) {
    final meta = (data['meta'] ?? '').toString().trim();
    if (meta.isNotEmpty) return meta;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      final d = raw.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return 'Posted ${d.year}-$mm-$dd';
    }
    return 'Posted recently';
  }

  String _categoryForData(Map<String, dynamic> data) {
    final raw = (data['category'] ?? 'General').toString().trim();
    if (raw.isEmpty) return 'General';
    if (_categories.contains(raw)) return raw;
    return 'General';
  }
}

class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    this.announcementId,
    this.data,
  });

  final String? announcementId;
  final Map<String, dynamic>? data;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final _service = AnnouncementsService();
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    _markReadAndView();
  }

  Future<void> _markReadAndView() async {
    if (_marked) return;
    final id = widget.announcementId;
    if (id == null || id.isEmpty) return;
    _marked = true;
    await _service.markRead(id);
    await _service.recordView(id);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;

    if (widget.announcementId != null) {
      return Theme(
        data: baseTheme.copyWith(textTheme: textTheme),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Announcement'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: dark,
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .doc(widget.announcementId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() ?? widget.data;
              if (data == null) {
                return const Center(child: Text('Announcement not found.'));
              }

              return _AnnouncementDetailBody(data: data);
            },
          ),
        ),
      );
    }

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Announcement'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: _AnnouncementDetailBody(data: widget.data ?? {}),
      ),
    );
  }
}

class _AnnouncementDetailBody extends StatelessWidget {
  const _AnnouncementDetailBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    final title = (data['title'] ?? 'Untitled').toString();
    final body = (data['body'] ?? '').toString();
    final meta = (data['meta'] ?? '').toString().trim();
    final category = (data['category'] ?? 'General').toString();
    final author =
        (data['createdByName'] ?? data['createdByEmail'] ?? '').toString();
    final createdAt = _formatDate(data['createdAt']);
    final media = data['media'] as Map<String, dynamic>?;
    final mediaUrl = (media?['url'] ?? '').toString();

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: ListView(
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
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.campaign, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CategoryPill(label: category),
                  const SizedBox(height: 12),
                  if (mediaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        mediaUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _mediaFallback(context),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _mediaFallback(context);
                        },
                      ),
                    ),
                  if (mediaUrl.isNotEmpty) const SizedBox(height: 12),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: textTheme.bodySmall?.copyWith(
                        color: dark.withValues(alpha: 0.6),
                      ),
                    ),
                  if (meta.isNotEmpty) const SizedBox(height: 6),
                  Text(
                    createdAt,
                    style: textTheme.bodySmall?.copyWith(
                      color: dark.withValues(alpha: 0.5),
                    ),
                  ),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Posted by $author',
                      style: textTheme.bodySmall?.copyWith(
                        color: dark.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: textTheme.bodyMedium?.copyWith(
                      color: dark.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaFallback(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: const Center(child: Icon(Icons.image, color: Colors.black45)),
    );
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return 'Posted ${d.year}-$mm-$dd | $hh:$min';
    }
    return 'Posted recently';
  }
}

class _AnnouncementThumb extends StatelessWidget {
  const _AnnouncementThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    if (url.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: const Icon(Icons.campaign, color: accent),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: const Icon(Icons.campaign, color: accent),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE46B2C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE46B2C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: Theme.of(context).colorScheme.surface,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

