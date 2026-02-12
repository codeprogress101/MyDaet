import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/user_context_service.dart';
import '../../../services/permissions.dart';
import '../data/dts_repository.dart';
import '../domain/dts_document.dart';
import '../domain/dts_timeline_event.dart';
import 'dts_initiate_transfer_screen.dart';
import 'dts_status.dart';

class DtsDocumentDetailScreen extends StatefulWidget {
  const DtsDocumentDetailScreen({super.key, required this.docId});

  final String docId;

  @override
  State<DtsDocumentDetailScreen> createState() =>
      _DtsDocumentDetailScreenState();
}

class _DtsDocumentDetailScreenState extends State<DtsDocumentDetailScreen> {
  final _repo = DtsRepository();
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;
  final Map<String, Future<String>> _nameCache = {};

  Future<String> _resolveUserName(String uid) {
    if (_nameCache.containsKey(uid)) return _nameCache[uid]!;
    final future = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .then((snap) {
      final data = snap.data() ?? {};
      final displayName = (data['displayName'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      if (displayName.isNotEmpty) return displayName;
      if (email.isNotEmpty) return email;
      return uid;
    }).catchError((_) => uid);
    _nameCache[uid] = future;
    return future;
  }

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  Future<void> _confirmReceipt(
    UserContext userContext,
    DtsDocument doc,
  ) async {
    final pending = doc.pendingTransfer;
    if (pending == null) return;
    if (userContext.officeId == null ||
        userContext.officeId != pending.toOfficeId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not the receiving office.')),
        );
      }
      return;
    }

    try {
      await _repo.confirmReceipt(
        docId: doc.id,
        toOfficeId: pending.toOfficeId,
        toOfficeName: userContext.officeName ?? 'Office',
        receiverUid: userContext.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt confirmed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(UserContext userContext, DtsDocument doc) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final statuses = DtsStatusHelper.values;
        return ListView.builder(
          itemCount: statuses.length,
          itemBuilder: (context, index) {
            final status = statuses[index];
            return ListTile(
              title: Text(DtsStatusHelper.label(status)),
              onTap: () => Navigator.of(context).pop(status),
            );
          },
        );
      },
    );
    if (selected == null) return;
    try {
      await _repo.updateStatus(
        docId: doc.id,
        status: selected,
        actorUid: userContext.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _addNote(UserContext userContext, DtsDocument doc) async {
    final result = await showDialog<_NoteInputResult>(
      context: context,
      builder: (context) {
        return _AddNoteDialog(repo: _repo, docId: doc.id);
      },
    );
    if (result == null) return;
    await _repo.addNote(
      docId: doc.id,
      actorUid: userContext.uid,
      notes: result.notes,
      attachments: result.attachments,
    );
  }

  void _initiateTransfer(DtsDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DtsInitiateTransferScreen(document: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = baseTheme.colorScheme;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: FutureBuilder<UserContext?>(
        future: _contextFuture,
        builder: (context, userSnap) {
          if (userSnap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final userContext = userSnap.data;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('dts_documents')
                .doc(widget.docId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Document Detail')),
                  body: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.data!.exists) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Document Detail')),
                  body: const Center(child: Text('Document not found.')),
                );
              }

              final doc = DtsDocument.fromDoc(snapshot.data!);
              final statusColor = DtsStatusHelper.color(context, doc.status);
              final statusLabel = DtsStatusHelper.label(doc.status);
              final coverUrl = doc.coverPhoto?['url']?.toString();
              final pending = doc.pendingTransfer;

              final ctx = userContext;
              final canConfirm = ctx != null &&
                  ctx.isStaff &&
                  pending != null &&
                  ctx.officeId != null &&
                  ctx.officeId == pending.toOfficeId;

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  title: const Text('Document Detail'),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor: scheme.onSurface,
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      doc.title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(label: statusLabel, color: statusColor),
                        _MetaChip(
                          label: doc.trackingNo,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                        _MetaChip(
                          label: doc.docType,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (coverUrl != null && coverUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          coverUrl,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    if (coverUrl != null) const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Office',
                      value: doc.currentOfficeName ?? doc.currentOfficeId,
                    ),
                    _InfoRow(
                      label: 'Confidentiality',
                      value: doc.confidentiality.toUpperCase(),
                    ),
                    if (doc.sourceName != null)
                      _InfoRow(
                        label: 'Source',
                        value: doc.sourceName!,
                      ),
                    if (pending != null)
                      _InfoRow(
                        label: 'Pending transfer',
                        value:
                            'To ${pending.toOfficeId}${pending.toUid != null ? ' (user)' : ''}',
                      ),
                    const SizedBox(height: 16),
                    if (ctx != null && ctx.isStaff)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _initiateTransfer(doc),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Transfer'),
                          ),
                          if (canConfirm)
                            FilledButton.icon(
                              onPressed: () => _confirmReceipt(ctx, doc),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Confirm receipt'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _updateStatus(ctx, doc),
                            icon: const Icon(Icons.update),
                            label: const Text('Update status'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _addNote(ctx, doc),
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('Add note'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (ctx != null && ctx.isStaff) ...[
                      Text(
                        'Timeline',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<DtsTimelineEvent>>(
                        stream: _repo.watchTimeline(doc.id),
                        builder: (context, timelineSnap) {
                          if (timelineSnap.hasError) {
                            return Text('Error: ${timelineSnap.error}');
                          }
                          if (!timelineSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final events = timelineSnap.data!;
                          if (events.isEmpty) {
                            return Text(
                              'No timeline events yet.',
                              style: textTheme.bodySmall?.copyWith(
                                color:
                                    scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            );
                          }
                        return Column(
                          children: events
                              .map(
                                (event) => _TimelineTile(
                                  event: event,
                                  nameFuture: event.byUid == null
                                      ? null
                                      : _resolveUserName(event.byUid!),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    ] else ...[
                      Text(
                        'Timeline updates are visible to staff only.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
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

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    this.nameFuture,
  });

  final DtsTimelineEvent event;
  final Future<String>? nameFuture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = event.createdAt;
    final timeLabel = when != null ? _formatDateTime(when) : '';

    final title = event.notes?.trim().isNotEmpty == true
        ? event.notes!.trim()
        : event.type.replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                color: scheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (nameFuture != null)
                    FutureBuilder<String>(
                      future: nameFuture,
                      builder: (context, snap) {
                        final name = snap.data ?? 'Unknown';
                        return Text(
                          'By $name',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                        );
                      },
                    ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteInputResult {
  final String notes;
  final List<Map<String, dynamic>> attachments;

  const _NoteInputResult({
    required this.notes,
    required this.attachments,
  });
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog({required this.repo, required this.docId});

  final DtsRepository repo;
  final String docId;

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _controller = TextEditingController();
  bool _uploading = false;
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addAttachment() async {
    if (_uploading) return;
    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    if (file.path == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await widget.repo.uploadAttachment(
        docId: widget.docId,
        file: File(file.path!),
        name: file.name,
      );
      if (!mounted) return;
      setState(() => _attachments.add(uploaded));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    final note = _controller.text.trim();
    if (note.isEmpty && _attachments.isEmpty) return;
    Navigator.of(context).pop(
      _NoteInputResult(notes: note, attachments: _attachments),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter note...',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _addAttachment,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _uploading
                  ? 'Uploading...'
                  : _attachments.isEmpty
                      ? 'Add attachment'
                      : 'Add another attachment',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
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
  int hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  if (hour == 0) hour = 12;
  if (hour > 12) hour -= 12;
  final m = months[dt.month - 1];
  final day = dt.day.toString().padLeft(2, '0');
  return '$m $day, ${dt.year} • $hour:$minute $ampm';
}
