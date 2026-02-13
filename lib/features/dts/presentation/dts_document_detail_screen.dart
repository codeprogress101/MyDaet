import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/user_context_service.dart';
import '../../../services/permissions.dart';
import '../../shared/timezone_utils.dart';
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
  final Map<String, Future<String?>> _qrImageCache = {};

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
        })
        .catchError((_) => uid);
    _nameCache[uid] = future;
    return future;
  }

  Future<String?> _resolveQrImageUrl(String qrCode) {
    if (_qrImageCache.containsKey(qrCode)) return _qrImageCache[qrCode]!;
    final future = _repo.resolveQrImageUrl(qrCode);
    _qrImageCache[qrCode] = future;
    return future;
  }

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  bool _canReceiveTransfer(
    UserContext userContext,
    DtsPendingTransfer? pending,
  ) {
    if (pending == null) return false;

    final officeIdMatch =
        userContext.officeId != null &&
        userContext.officeId == pending.toOfficeId;
    final officeNameMatch =
        userContext.officeName != null &&
        pending.toOfficeName != null &&
        userContext.officeName!.trim().toLowerCase() ==
            pending.toOfficeName!.trim().toLowerCase();
    final recipientMatch =
        pending.toUid != null && pending.toUid == userContext.uid;

    return officeIdMatch || officeNameMatch || recipientMatch;
  }

  bool _canCancelTransfer(UserContext userContext, DtsDocument doc) {
    final pending = doc.pendingTransfer;
    if (pending == null || !userContext.isStaff) return false;
    if (userContext.isSuperAdmin) return true;

    final initiatedByCurrentUser =
        pending.fromUid != null && pending.fromUid == userContext.uid;
    final fromOfficeById =
        userContext.officeId != null &&
        userContext.officeId == pending.fromOfficeId;
    final fromOfficeByName =
        userContext.officeName != null &&
        doc.currentOfficeName != null &&
        userContext.officeName!.trim().toLowerCase() ==
            doc.currentOfficeName!.trim().toLowerCase();

    return initiatedByCurrentUser || fromOfficeById || fromOfficeByName;
  }

  Future<void> _confirmReceipt(UserContext userContext, DtsDocument doc) async {
    final pending = doc.pendingTransfer;
    if (pending == null) return;
    if (!_canReceiveTransfer(userContext, pending)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are not the receiving office for this transfer.',
            ),
          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Receipt confirmed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _cancelTransfer(UserContext userContext, DtsDocument doc) async {
    final pending = doc.pendingTransfer;
    if (pending == null) return;
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel transfer?'),
          content: const Text(
            'This will stop the in-transit transfer and return custody to the source office.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep transfer'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel transfer'),
            ),
          ],
        );
      },
    );
    if (shouldCancel != true) return;

    try {
      await _repo.cancelTransfer(
        docId: doc.id,
        actorUid: userContext.uid,
        fallbackOfficeId: doc.currentOfficeId,
        fallbackOfficeName:
            doc.currentOfficeName ?? userContext.officeName ?? 'Office',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer cancelled.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
      final actorName = await _resolveUserName(userContext.uid);
      await _repo.updateStatus(
        docId: doc.id,
        status: selected,
        actorUid: userContext.uid,
        actorName: actorName,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _addNote(UserContext userContext, DtsDocument doc) async {
    final result = await showDialog<_NoteInputResult>(
      context: context,
      builder: (context) {
        return _AddNoteDialog(
          repo: _repo,
          docId: doc.id,
          title: 'Add note',
          hintText: 'Enter note...',
          confirmText: 'Save',
        );
      },
    );
    if (result == null) return;
    try {
      await _repo.addNote(
        docId: doc.id,
        actorUid: userContext.uid,
        notes: result.notes,
        attachments: result.attachments,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note added.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add note: $e')));
    }
  }

  Future<void> _rejectTransfer(UserContext userContext, DtsDocument doc) async {
    final pending = doc.pendingTransfer;
    if (pending == null) return;

    final result = await showDialog<_NoteInputResult>(
      context: context,
      builder: (context) {
        return _AddNoteDialog(
          repo: _repo,
          docId: doc.id,
          title: 'Reject transfer',
          hintText: 'Why is this transfer rejected?',
          confirmText: 'Reject transfer',
          requireNote: true,
        );
      },
    );
    if (result == null) return;

    try {
      await _repo.rejectTransfer(
        docId: doc.id,
        actorUid: userContext.uid,
        reason: result.notes,
        attachments: result.attachments,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transfer rejected.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reject transfer: $e')));
    }
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
                final err = snapshot.error;
                String message = 'Unable to open this document.';
                if (err is FirebaseException &&
                    (err.code == 'permission-denied' ||
                        err.code == 'unauthenticated')) {
                  message =
                      'You cannot open this document. This transfer may be assigned to another office.';
                }
                return Scaffold(
                  appBar: AppBar(title: const Text('Document Detail')),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(message, textAlign: TextAlign.center),
                    ),
                  ),
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
              final staffContext = (ctx != null && ctx.isStaff) ? ctx : null;
              final isStaff = staffContext != null;
              final receiverLocked =
                  pending != null &&
                  staffContext != null &&
                  _canReceiveTransfer(staffContext, pending);
              final canCancelTransfer =
                  staffContext != null && _canCancelTransfer(staffContext, doc);
              final canViewPin =
                  doc.trackingPin != null &&
                  doc.trackingPin!.trim().isNotEmpty &&
                  ctx != null &&
                  (ctx.isStaff || doc.submittedByUid == ctx.uid);

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            doc.title,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (doc.qrCode.trim().isNotEmpty)
                          _QrThumbButton(
                            qrCode: doc.qrCode,
                            imageUrlFuture: _resolveQrImageUrl(doc.qrCode),
                          ),
                      ],
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
                        if (canViewPin)
                          _MetaChip(
                            label: 'PIN ${doc.trackingPin!}',
                            color: scheme.primary,
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
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    if (coverUrl != null) const SizedBox(height: 12),
                    if (doc.qrCode.trim().isNotEmpty)
                      _InfoRow(label: 'QR Code', value: doc.qrCode),
                    _InfoRow(label: 'Tracking No', value: doc.trackingNo),
                    if (ctx != null && ctx.isStaff)
                      _InfoRow(
                        label: 'PIN',
                        value: doc.trackingPin?.trim().isNotEmpty == true
                            ? doc.trackingPin!
                            : 'Not stored (legacy record)',
                      ),
                    _InfoRow(
                      label: 'Office',
                      value: doc.currentOfficeName ?? doc.currentOfficeId,
                    ),
                    _InfoRow(
                      label: 'Confidentiality',
                      value: doc.confidentiality.toUpperCase(),
                    ),
                    if (doc.sourceName != null)
                      _InfoRow(label: 'Source', value: doc.sourceName!),
                    if (pending != null)
                      _InfoRow(
                        label: 'Pending transfer',
                        value:
                            'To ${pending.toOfficeName ?? pending.toOfficeId}${pending.toUid != null ? ' (specific recipient)' : ''}',
                      ),
                    const SizedBox(height: 16),
                    if (isStaff)
                      if (receiverLocked) ...[
                        Text(
                          'This document is in transit to your office. Confirm or reject receipt to continue.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  _confirmReceipt(staffContext, doc),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Confirm receipt'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _rejectTransfer(staffContext, doc),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ] else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (pending == null)
                              OutlinedButton.icon(
                                onPressed: () => _initiateTransfer(doc),
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Transfer'),
                              ),
                            if (pending != null && canCancelTransfer)
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    _cancelTransfer(staffContext, doc),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel transfer'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _updateStatus(staffContext, doc),
                              icon: const Icon(Icons.update),
                              label: const Text('Update status'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _addNote(staffContext, doc),
                              icon: const Icon(Icons.note_add_outlined),
                              label: const Text('Add note'),
                            ),
                          ],
                        ),
                    const SizedBox(height: 16),
                    if (isStaff) ...[
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
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            );
                          }
                          return Column(
                            children: events
                                .map(
                                  (event) => _TimelineTile(
                                    event: event,
                                    nameFuture: event.byName != null
                                        ? Future.value(event.byName)
                                        : event.byUid == null
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

class _QrThumbButton extends StatelessWidget {
  const _QrThumbButton({required this.qrCode, required this.imageUrlFuture});

  final String qrCode;
  final Future<String?> imageUrlFuture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String?>(
      future: imageUrlFuture,
      builder: (context, snap) {
        final imageUrl = snap.data;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: imageUrl == null || imageUrl.isEmpty
              ? null
              : () {
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => Dialog(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              qrCode,
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 280,
                              height: 280,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text('Unable to load QR image.'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
          child: Container(
            width: 54,
            height: 54,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(imageUrl, fit: BoxFit.cover),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.open_in_full,
                              size: 12,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      snap.connectionState == ConnectionState.waiting
                          ? Icons.hourglass_top
                          : Icons.qr_code_2,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
            ),
          ),
        );
      },
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
        border: Border.all(color: Theme.of(context).dividerColor),
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
  const _TimelineTile({required this.event, this.nameFuture});

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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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

  const _NoteInputResult({required this.notes, required this.attachments});
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog({
    required this.repo,
    required this.docId,
    required this.title,
    required this.hintText,
    required this.confirmText,
    this.requireNote = false,
  });

  final DtsRepository repo;
  final String docId;
  final String title;
  final String hintText;
  final String confirmText;
  final bool requireNote;

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Attachment upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    final note = _controller.text.trim();
    if (widget.requireNote && note.isEmpty) return;
    if (note.isEmpty && _attachments.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_NoteInputResult(notes: note, attachments: _attachments));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(hintText: widget.hintText),
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
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}

String _formatDateTime(DateTime dt) {
  return formatManilaDateTime(dt, includeZone: true);
}
