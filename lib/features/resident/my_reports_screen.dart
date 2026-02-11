import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/search_field.dart';
import '../shared/report_status.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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

  void _retry() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE46B2C);
    final dark = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;
    final user = FirebaseAuth.instance.currentUser;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: AppScaffold(
        title: 'My Reports',
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBarBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBarForegroundColor: dark,
        body: user == null
            ? const EmptyState(
                title: 'Not logged in',
                subtitle: 'Please sign in to view your reports.',
              )
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .where('createdByUid', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      title: 'Unable to load reports',
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
                  final docs = snapshot.data!.docs.toList();
                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No reports yet',
                      subtitle: 'Create a report to get started.',
                    );
                  }

                  docs.sort((a, b) {
                    final ad = a.data() as Map<String, dynamic>;
                    final bd = b.data() as Map<String, dynamic>;
                    final at = ad['createdAt'] as Timestamp?;
                    final bt = bd['createdAt'] as Timestamp?;
                    final adt =
                        at?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bdt =
                        bt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bdt.compareTo(adt);
                  });

                  final q = _query.trim().toLowerCase();
                  final filteredDocs = q.isEmpty
                      ? docs
                      : docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title =
                              (data['title'] ?? '').toString().toLowerCase();
                          final status =
                              (data['status'] ?? '').toString().toLowerCase();
                          return title.contains(q) || status.contains(q);
                        }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SearchField(
                        controller: _searchController,
                        hintText: 'Search reports...',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 12),
                      if (isOffline) ...[
                        _OfflineBanner(textTheme: textTheme),
                        const SizedBox(height: 8),
                      ],
                      if (filteredDocs.isEmpty)
                        Text(
                          'No reports match "$q".',
                          style: textTheme.bodyMedium?.copyWith(
                            color: dark.withValues(alpha: 0.6),
                          ),
                        )
                      else
                        for (var i = 0; i < filteredDocs.length; i++) ...[
                          Builder(
                            builder: (context) {
                              final doc = filteredDocs[i];
                              final data = doc.data() as Map<String, dynamic>;
                              final title =
                                  (data['title'] as String?)?.trim().isNotEmpty ==
                                          true
                                      ? data['title'] as String
                                      : 'Untitled report';
                              final status =
                                  (data['status'] as String?)?.trim().isNotEmpty ==
                                          true
                                      ? data['status'] as String
                                      : 'submitted';
                              final createdAt =
                                  data['createdAt'] as Timestamp?;
                              final updatedAt =
                                  data['updatedAt'] as Timestamp?;
                              final date = (updatedAt ?? createdAt)?.toDate();
                              final dateLabel =
                                  date != null ? _formatDate(date) : null;
                              final statusRaw = status;
                              final statusPretty =
                                  ReportStatusHelper.pretty(statusRaw);
                              final statusColor = _statusColor(statusRaw);

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: Color(0xFFE5E0DA),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReportDetailScreen(
                                          reportId: doc.id,
                                          initialData: data,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.assignment_outlined,
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: dark,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  _statusPill(
                                                    label: statusPretty,
                                                    color: statusColor,
                                                  ),
                                                  if (dateLabel != null)
                                                    _metaPill(
                                                      label:
                                                          'Updated $dateLabel',
                                                      border: border,
                                                      textColor:
                                                          dark.withValues(alpha: 0.7),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (i != filteredDocs.length - 1)
                            const SizedBox(height: 8),
                        ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E0DA)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFE46B2C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline. Showing cached reports.',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _statusPill({
  required String label,
  required Color color,
}) {
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

Widget _metaPill({
  required String label,
  required Color border,
  required Color textColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Color _statusColor(String status) {
  switch (ReportStatusHelper.normalize(status)) {
    case 'in_review':
      return const Color(0xFF3A7BD5);
    case 'assigned':
      return const Color(0xFF5B7C99);
    case 'resolved':
      return const Color(0xFF2E7D32);
    case 'rejected':
      return const Color(0xFFC62828);
    case 'submitted':
    default:
      return const Color(0xFFE46B2C);
  }
}

String _formatDate(DateTime dt) {
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
  return '$m $day, $year';
}
