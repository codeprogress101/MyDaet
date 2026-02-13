import 'package:flutter/material.dart';

import '../../../services/user_context_service.dart';
import '../../../services/permissions.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/timezone_utils.dart';
import '../data/dts_repository.dart';
import '../domain/dts_document.dart';
import 'dts_document_detail_screen.dart';
import 'dts_qr_management_screen.dart';
import 'dts_scan_qr_screen.dart';
import 'dts_status.dart';
import 'dts_track_document_screen.dart';
import 'dts_my_documents_screen.dart';

class DtsHomeScreen extends StatefulWidget {
  const DtsHomeScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<DtsHomeScreen> createState() => _DtsHomeScreenState();
}

class _DtsHomeScreenState extends State<DtsHomeScreen> {
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<UserContext?>(
      future: _contextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final userContext = snapshot.data;
        if (userContext == null) {
          return const Center(child: Text('Please sign in to continue.'));
        }

        if (userContext.isStaff) {
          return _StaffHome(userContext: userContext);
        }
        return const _ResidentHome();
      },
    );

    if (!widget.showAppBar) {
      return content;
    }

    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Documents',
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBarBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBarForegroundColor: scheme.onSurface,
      body: content,
    );
  }
}

class _ResidentHome extends StatelessWidget {
  const _ResidentHome();

  void _openTrack(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DtsTrackDocumentScreen()));
  }

  void _openMyDocs(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DtsMyDocumentsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Document Tracking',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Track your submitted documents or check the status of hard-copy submissions.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        _ActionCard(
          title: 'Track a document',
          subtitle: 'Use tracking number + PIN to check status.',
          icon: Icons.qr_code_scanner,
          onTap: () => _openTrack(context),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'My documents',
          subtitle: 'View documents you submitted online.',
          icon: Icons.folder_open_outlined,
          onTap: () => _openMyDocs(context),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            color: scheme.surface,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'If you submitted a hard copy, ask the Records Clerk for your tracking number and PIN.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffHome extends StatefulWidget {
  const _StaffHome({required this.userContext});

  final UserContext userContext;

  @override
  State<_StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<_StaffHome> {
  final _repo = DtsRepository();
  bool _generating = false;

  void _openScan(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DtsScanQrScreen()));
  }

  Future<void> _generateBatch() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final codes = await _repo.generateQrCodes(count: 10);
      if (!mounted) return;
      await showDialog<void>(
        context: this.context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Generated QR Codes'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: codes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  return Text(codes[index]);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate QR: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final userContext = widget.userContext;
    final title = userContext.isSuperAdmin
        ? 'All Documents'
        : (userContext.officeName?.trim().isNotEmpty == true
              ? '${userContext.officeName} Queue'
              : 'Office Queue');

    return StreamBuilder<List<DtsDocument>>(
      stream: _repo.watchOfficeQueue(userContext),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (userContext.isSuperAdmin) ...[
                  OutlinedButton.icon(
                    onPressed: _generating ? null : _generateBatch,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(_generating ? 'Generating...' : 'Generate 10'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'QR Management',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DtsQrManagementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.manage_search),
                  ),
                ],
                FilledButton.icon(
                  onPressed: () => _openScan(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Center(
                child: Text(
                  'No documents available.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DocumentCard(doc: doc),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc});

  final DtsDocument doc;

  void _openDetail(BuildContext context) {
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
    final officeLabel = doc.currentOfficeName?.trim().isNotEmpty == true
        ? doc.currentOfficeName!.trim()
        : doc.currentOfficeId;
    final time = doc.updatedAt ?? doc.createdAt;
    final timeLabel = time != null ? _formatTime(time) : '';
    final metaParts = <String>[
      if (officeLabel.isNotEmpty) officeLabel,
      doc.trackingNo,
      if (timeLabel.isNotEmpty) timeLabel,
    ];

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(
                      label: DtsStatusHelper.label(doc.status),
                      color: statusColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      metaParts.join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 14, bottom: 14),
              child: Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
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

String _formatTime(DateTime dt) {
  return formatManilaTime(dt, includeZone: true);
}
