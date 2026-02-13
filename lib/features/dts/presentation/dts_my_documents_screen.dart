import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/timezone_utils.dart';
import '../data/dts_repository.dart';
import '../domain/dts_document.dart';
import 'dts_document_detail_screen.dart';
import 'dts_status.dart';

class DtsMyDocumentsScreen extends StatelessWidget {
  const DtsMyDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = baseTheme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('My Documents'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: scheme.onSurface,
        ),
        body: user == null
            ? const Center(child: Text('Please sign in to continue.'))
            : StreamBuilder<List<DtsDocument>>(
                stream: DtsRepository().watchMyDocuments(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No documents yet.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _DocCard(doc: doc);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc});

  final DtsDocument doc;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DtsDocumentDetailScreen(docId: doc.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = scheme.outlineVariant.withValues(alpha: 0.5);
    final statusColor = DtsStatusHelper.color(context, doc.status);
    final title = doc.title.isNotEmpty ? doc.title : 'Untitled document';
    final time = doc.updatedAt ?? doc.createdAt;
    final timeLabel = time != null ? _formatDate(time) : '';

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 64,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(
                      label: DtsStatusHelper.label(doc.status),
                      color: statusColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        doc.trackingNo,
                        if (timeLabel.isNotEmpty) timeLabel,
                      ].join(' - '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (doc.trackingPin != null &&
                        doc.trackingPin!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'PIN: ${doc.trackingPin}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}

String _formatDate(DateTime dt) {
  return formatManilaDateTime(dt, includeZone: true);
}
