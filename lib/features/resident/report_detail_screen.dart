import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/empty_state.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.reportId,
    this.initialData,
  });

  final String reportId;
  final Map<String, dynamic>? initialData;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  void _retry() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = baseTheme.colorScheme.onSurface;
    final bg = baseTheme.scaffoldBackgroundColor;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: AppScaffold(
        title: 'Report Detail',
        backgroundColor: bg,
        appBarBackgroundColor: bg,
        appBarForegroundColor: dark,
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .doc(widget.reportId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return EmptyState(
                title: 'Unable to load report',
                subtitle: '${snapshot.error}',
                action: TextButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              );
            }

            final data = snapshot.data?.data() ?? widget.initialData;
            final isOffline = snapshot.data?.metadata.isFromCache ?? false;
            if (snapshot.connectionState == ConnectionState.waiting &&
                data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (data == null) {
              return const EmptyState(
                title: 'Report not found',
                subtitle: 'This report may have been removed.',
              );
            }

            return _ReportDetailBody(
              data: data,
              reportId: widget.reportId,
              isOffline: isOffline,
            );
          },
        ),
      ),
    );
  }
}

class _ReportDetailBody extends StatelessWidget {
  const _ReportDetailBody({
    required this.data,
    required this.reportId,
    required this.isOffline,
  });

  final Map<String, dynamic> data;
  final String reportId;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dark = theme.colorScheme.onSurface;
    final muted = dark.withOpacity(0.7);
    final border = theme.dividerColor;

    final title = _string(data['title'], fallback: 'Untitled report');
    final description = _string(data['description']);
    final contactNumber = _string(data['contactNumber']);
    final category = _string(data['category'], fallback: 'Uncategorized');
    final status = _string(data['status'], fallback: 'submitted');
    final createdAt = _timestamp(data['createdAt']);
    final createdAtLabel =
        createdAt != null ? _formatDateTime(createdAt.toDate()) : 'Unknown date';

    final location = data['location'] is Map
        ? Map<String, dynamic>.from(data['location'] as Map)
        : <String, dynamic>{};
    final address = _string(location['address']);
    final lat = location['lat'];
    final lng = location['lng'];

    final attachments = _parseAttachments(data['attachments']);
    final imageAttachments = attachments.where(_isImage).toList();
    final fileAttachments = attachments.where((a) => !_isImage(a)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOffline) const _OfflineBanner(),
        if (isOffline) const SizedBox(height: 12),
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge?.copyWith(color: dark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    label: category,
                    icon: Icons.category_outlined,
                    color: Theme.of(context).colorScheme.surface,
                    textColor: dark,
                    borderColor: border,
                  ),
                  _chip(
                    label: _prettyStatus(status),
                    icon: Icons.circle,
                    iconColor: _statusColor(status),
                    color: _statusColor(status).withOpacity(0.12),
                    textColor: dark,
                    borderColor: _statusColor(status).withOpacity(0.25),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: dark),
                  const SizedBox(width: 6),
                  Text(
                    'Created: $createdAtLabel',
                    style: textTheme.bodySmall?.copyWith(
                      color: muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Tracking'),
        const SizedBox(height: 8),
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _etaRow(context, status, textTheme),
              const SizedBox(height: 12),
              _statusTimeline(context, status, textTheme),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Description'),
        const SizedBox(height: 8),
        _card(
          context,
          child: Text(
            description.isNotEmpty ? description : 'No description provided.',
            style: textTheme.bodyMedium?.copyWith(color: dark),
          ),
        ),
        if (contactNumber.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle(context, 'Contact Number'),
          const SizedBox(height: 8),
          _card(
            context,
            child: Text(
              contactNumber,
              style: textTheme.bodyMedium?.copyWith(color: dark),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle(context, 'Location'),
        const SizedBox(height: 8),
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address.isNotEmpty)
                Text(
                  address,
                  style: textTheme.bodyMedium?.copyWith(color: dark),
                ),
              if (address.isNotEmpty) const SizedBox(height: 6),
              if (lat is num && lng is num)
                Text(
                  '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: muted,
                  ),
                )
              else
                Text(
                  'Location not available.',
                  style: textTheme.bodySmall?.copyWith(
                    color: muted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Attachments'),
        const SizedBox(height: 8),
        if (attachments.isEmpty)
          _card(
            context,
            child: Text(
              'No attachments uploaded.',
              style: textTheme.bodyMedium?.copyWith(color: dark),
            ),
          )
        else ...[
          if (imageAttachments.isNotEmpty) ...[
            _card(
              context,
              child: imageAttachments.length == 1
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final size = maxWidth < 320 ? maxWidth : 320.0;
                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: _imageTile(
                              context,
                              _string(imageAttachments.first['url']),
                            ),
                          ),
                        );
                      },
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: imageAttachments.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = imageAttachments[index];
                        final url = _string(item['url']);
                        return _imageTile(context, url);
                      },
                    ),
            ),
            const SizedBox(height: 10),
          ],
          if (fileAttachments.isNotEmpty)
            _card(
              context,
              child: Column(
                children: fileAttachments
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _string(item['name'],
                                    fallback: 'Attachment'),
                                style: textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatBytes(_int(item['size'])),
                              style: textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
        const SizedBox(height: 12),
        _sectionTitle(context, 'Status History'),
        const SizedBox(height: 8),
        _historySection(context, reportId, textTheme),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Notes'),
        const SizedBox(height: 8),
        _notesSection(context, reportId, textTheme),
      ],
    );
  }
}

Widget _sectionTitle(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
  );
}

Widget _card(BuildContext context, {required Widget child}) {
  final borderColor = Theme.of(context).dividerColor;
  final surface = Theme.of(context).colorScheme.surface;
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: borderColor),
    ),
    color: surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    final surface = Theme.of(context).colorScheme.surface;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      color: surface,
      child: const ListTile(
        leading: Icon(Icons.wifi_off, color: Color(0xFFE46B2C)),
        title: Text(
          'Offline',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Showing cached report.'),
      ),
    );
  }
}

Widget _etaRow(BuildContext context, String status, TextTheme textTheme) {
  final etaText = _statusEta(status);
  final color = _statusColor(status);
  return Row(
    children: [
      Icon(Icons.timelapse, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          etaText,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ],
  );
}

Widget _statusTimeline(
  BuildContext context,
  String status,
  TextTheme textTheme,
) {
  final steps = _timelineSteps(status);
  final currentIndex = steps.indexOf(status);
  final activeColor = _statusColor(status);
  final border = Theme.of(context).dividerColor;
  final onSurface = Theme.of(context).colorScheme.onSurface;

  return Column(
    children: List.generate(steps.length, (index) {
      final step = steps[index];
      final isDone = currentIndex >= 0 ? index <= currentIndex : index == 0;
      final isLast = index == steps.length - 1;
      final color = isDone ? activeColor : border;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 26,
                    color: color.withOpacity(0.8),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _prettyStatus(step),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isDone ? onSurface : onSurface.withOpacity(0.54),
                ),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

List<String> _timelineSteps(String status) {
  if (status == 'rejected') {
    return const ['submitted', 'in_review', 'rejected'];
  }
  return const ['submitted', 'in_review', 'assigned', 'in_progress', 'resolved'];
}

String _statusEta(String status) {
  switch (status) {
    case 'submitted':
      return 'ETA: 3-5 days';
    case 'in_review':
      return 'ETA: 2-4 days';
    case 'assigned':
      return 'ETA: 1-3 days';
    case 'in_progress':
      return 'ETA: 24-48 hours';
    case 'resolved':
      return 'Resolved';
    case 'rejected':
      return 'Closed (rejected)';
    default:
      return 'ETA: pending';
  }
}

Widget _historySection(
  BuildContext context,
  String reportId,
  TextTheme textTheme,
) {
  if (reportId.isEmpty) {
    return _card(
      context,
      child: Text(
        'No history available.',
        style: textTheme.bodyMedium,
      ),
    );
  }

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _card(
          context,
          child: Text(
            'Unable to load history.',
            style: textTheme.bodyMedium,
          ),
        );
      }

      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return _card(
          context,
          child: Text(
            'No history yet.',
            style: textTheme.bodyMedium,
          ),
        );
      }

      return Column(
        children: docs.map((doc) {
          final data = doc.data();
          final createdAt = data['createdAt'] as Timestamp?;
          final when = createdAt != null
              ? _formatDateTime(createdAt.toDate())
              : 'Just now';
          final message = _historyLabel(data);
          return _card(
            context,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message, style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        when,
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

String _historyLabel(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  switch (type) {
    case 'created':
      return 'Report created.';
    case 'status_changed':
      final from = (data['fromStatus'] ?? '').toString();
      final to = (data['toStatus'] ?? '').toString();
      if (from.isEmpty || to.isEmpty) return 'Status updated.';
      return 'Status changed from ${_prettyStatus(from)} to ${_prettyStatus(to)}.';
    case 'assignment_changed':
      final to = (data['toAssignedUid'] ?? '').toString();
      if (to.isEmpty) return 'Report unassigned.';
      return 'Report assigned.';
    case 'archived':
      return 'Report archived.';
    case 'restored':
      return 'Report restored.';
    default:
      return (data['message'] ?? 'Report updated.').toString();
  }
}

Widget _notesSection(
  BuildContext context,
  String reportId,
  TextTheme textTheme,
) {
  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _card(
          context,
          child: Text(
            'Unable to load notes.',
            style: textTheme.bodyMedium,
          ),
        );
      }

      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return _card(
          context,
          child: Text(
            'No notes yet.',
            style: textTheme.bodyMedium,
          ),
        );
      }

      return Column(
        children: docs.map((doc) {
          final data = doc.data();
          final text = _string(data['text']);
          final attachments = _parseAttachments(data['attachments']);
          final imageAttachments = attachments.where(_isImage).toList();
          final fileAttachments = attachments.where((a) => !_isImage(a)).toList();
          final createdAt = data['createdAt'] as Timestamp?;
          final when = createdAt != null
              ? _formatDateTime(createdAt.toDate())
              : 'Just now';

          final authorName = _string(data['createdByName']);
          final authorEmail = _string(data['createdByEmail']);
          final authorRole = _string(data['createdByRole'], fallback: 'staff');
          String author = '';
          if (authorName.isNotEmpty && authorEmail.isNotEmpty) {
            author = '$authorName • $authorEmail';
          } else if (authorName.isNotEmpty) {
            author = authorName;
          } else if (authorEmail.isNotEmpty) {
            author = authorEmail;
          } else {
            author = authorRole.toUpperCase();
          }

          return _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text, style: textTheme.bodyMedium),
                ],
                if (imageAttachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: imageAttachments.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = imageAttachments[index];
                      final url = _string(item['url']);
                      return _imageTile(context, url);
                    },
                  ),
                ],
                if (fileAttachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...fileAttachments.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _string(item['name'], fallback: 'Attachment'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatBytes(_int(item['size'])),
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  when,
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

Widget _chip({
  required String label,
  required IconData icon,
  required Color color,
  required Color textColor,
  required Color borderColor,
  Color? iconColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: iconColor ?? textColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _imageTile(BuildContext context, String url) {
  return InkWell(
    onTap: url.isEmpty ? null : () => _openImage(context, url),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF4EFEA),
        child: url.isEmpty
            ? const Center(child: Icon(Icons.broken_image))
            : Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
      ),
    ),
  );
}

void _openImage(BuildContext context, String url) {
  if (url.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullScreenImage(url: url),
    ),
  );
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.white),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final s = value.toString().trim();
  return s.isEmpty ? fallback : s;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

Timestamp? _timestamp(dynamic value) {
  if (value is Timestamp) return value;
  return null;
}

List<Map<String, dynamic>> _parseAttachments(dynamic raw) {
  if (raw is! List) return [];
  final List<Map<String, dynamic>> items = [];
  for (final item in raw) {
    if (item is Map) {
      items.add(Map<String, dynamic>.from(item));
    }
  }
  return items;
}

bool _isImage(Map<String, dynamic> item) {
  final contentType = _string(item['contentType']).toLowerCase();
  if (contentType.startsWith('image/')) return true;
  final name = _string(item['name']).toLowerCase();
  return name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.gif') ||
      name.endsWith('.webp');
}

Color _statusColor(String status) {
  switch (status) {
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

String _prettyStatus(String status) {
  return status.replaceAll('_', ' ').trim();
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

String _formatBytes(int? bytes) {
  if (bytes == null) return 'Unknown size';
  if (bytes < 1024) return '${bytes} B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}
