import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/user_context_service.dart';
import '../../../services/permissions.dart';
import '../data/dts_repository.dart';

class DtsQrManagementScreen extends StatefulWidget {
  const DtsQrManagementScreen({super.key});

  @override
  State<DtsQrManagementScreen> createState() => _DtsQrManagementScreenState();
}

class _DtsQrManagementScreenState extends State<DtsQrManagementScreen> {
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('dts_qr_codes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _exportZip(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR codes to export.')),
        );
      }
      return;
    }

    try {
      final codes = docs
          .take(10)
          .map((doc) => (doc.data()['qrCode'] ?? doc.id).toString())
          .toList();
      final repo = DtsRepository();
      final url = await repo.exportQrZip(codes: codes);
      if (!mounted) return;
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. No download URL.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('QR Export Ready'),
            content: const Text(
              'Your ZIP file is ready for download.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final uri = Uri.parse(url);
                  final ok = await canLaunchUrl(uri);
                  if (!ok) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to open download URL.')),
                    );
                    return;
                  }
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: const Text('Download'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _previewQr(String imagePath, String code) async {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(code),
          content: SizedBox(
            width: 220,
            height: 220,
            child: FutureBuilder<String>(
              future: FirebaseStorage.instance.ref(imagePath).getDownloadURL(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError || !snap.hasData) {
                  return const Center(child: Text('Unable to load QR image.'));
                }
                return Image.network(snap.data!, fit: BoxFit.contain);
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
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = baseTheme.colorScheme;
    final border = Theme.of(context).dividerColor;

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
          if (userContext == null || !userContext.isSuperAdmin) {
            return const Scaffold(
              body: Center(child: Text('Not authorized.')),
            );
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('QR Management'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: scheme.onSurface,
            ),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;
                final query = _search.text.trim().toLowerCase();

                List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered =
                    allDocs.where((doc) {
                  final data = doc.data();
                  final code = (data['qrCode'] ?? doc.id)
                      .toString()
                      .toLowerCase();
                  final status = (data['status'] ?? 'unused')
                      .toString()
                      .toLowerCase();
                  if (_filter != 'all' && status != _filter) return false;
                  if (query.isEmpty) return true;
                  return code.contains(query);
                }).toList();

                final unusedCount = allDocs
                    .where((d) => (d.data()['status'] ?? 'unused') == 'unused')
                    .length;
                final usedCount = allDocs
                    .where((d) => (d.data()['status'] ?? '') == 'used')
                    .length;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search QR code',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _chip(
                            context,
                            label: 'All (${allDocs.length})',
                            selected: _filter == 'all',
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            context,
                            label: 'Unused ($unusedCount)',
                            selected: _filter == 'unused',
                            onTap: () => setState(() => _filter = 'unused'),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            context,
                            label: 'Used ($usedCount)',
                            selected: _filter == 'used',
                            onTap: () => setState(() => _filter = 'used'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total: ${filtered.length}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _exportZip(filtered),
                          icon: const Icon(Icons.archive),
                          label: const Text('Export ZIP (10)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Text(
                        'No QR codes found.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      )
                    else
                      ...filtered.map((doc) {
                        final data = doc.data();
                        final code =
                            (data['qrCode'] ?? doc.id).toString();
                        final status =
                            (data['status'] ?? 'unused').toString();
                        final imagePath =
                            (data['imagePath'] ?? '').toString();
                        final usedAt = _formatTimestamp(data['usedAt']);
                        final docId =
                            (data['docId'] ?? '').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: scheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: ListTile(
                              title: Text(code),
                              subtitle: Text(
                                status == 'used'
                                    ? 'Used • $usedAt'
                                    : 'Unused',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (imagePath.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Preview',
                                      onPressed: () =>
                                          _previewQr(imagePath, code),
                                      icon: const Icon(Icons.qr_code_2),
                                    ),
                                  if (docId.isNotEmpty)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Widget _chip(
  BuildContext context, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  final bg = selected
      ? scheme.primary.withValues(alpha: 0.12)
      : scheme.surface;
  final border = selected
      ? scheme.primary.withValues(alpha: 0.3)
      : scheme.outlineVariant;
  final color =
      selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7);

  return Material(
    color: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

String _formatTimestamp(dynamic raw) {
  if (raw is Timestamp) {
    final dt = raw.toDate();
    return dt.toIso8601String();
  }
  return '';
}
