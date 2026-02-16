import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/timezone_utils.dart';
import '../data/dts_repository.dart';
import '../domain/dts_document.dart';
import 'dts_document_detail_screen.dart';
import 'dts_status.dart';

class DtsMyDocumentsScreen extends StatefulWidget {
  const DtsMyDocumentsScreen({super.key});

  @override
  State<DtsMyDocumentsScreen> createState() => _DtsMyDocumentsScreenState();
}

class _DtsMyDocumentsScreenState extends State<DtsMyDocumentsScreen> {
  static const _prefsPrefix = 'dts_my_docs_prefs_';
  final Map<String, String> _aliases = <String, String>{};
  final Set<String> _archivedDocIds = <String>{};
  final Set<String> _revealedPinDocIds = <String>{};
  bool _showArchived = false;
  bool _loadingPrefs = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _prefsKey => '$_prefsPrefix${_user?.uid ?? 'anon'}';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _loadingPrefs = false);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (!mounted) return;
        setState(() => _loadingPrefs = false);
        return;
      }
      final aliases = <String, String>{};
      final archived = <String>{};
      for (final entry in decoded.entries) {
        final docId = entry.key.toString();
        if (entry.value is! Map) continue;
        final row = Map<String, dynamic>.from(entry.value as Map);
        final alias = (row['alias'] ?? '').toString().trim();
        final archivedFlag = row['archived'] == true;
        if (alias.isNotEmpty) aliases[docId] = alias;
        if (archivedFlag) archived.add(docId);
      }
      if (!mounted) return;
      setState(() {
        _aliases
          ..clear()
          ..addAll(aliases);
        _archivedDocIds
          ..clear()
          ..addAll(archived);
        _loadingPrefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, Map<String, dynamic>>{};
    final docIds = <String>{..._aliases.keys, ..._archivedDocIds};
    for (final docId in docIds) {
      payload[docId] = <String, dynamic>{
        'alias': _aliases[docId] ?? '',
        'archived': _archivedDocIds.contains(docId),
      };
    }
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  Future<void> _renameDoc(DtsDocument doc) async {
    final controller = TextEditingController(text: _aliases[doc.id] ?? '');
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename locally'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'e.g. Barangay Clearance',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (alias == null) return;
    setState(() {
      if (alias.isEmpty) {
        _aliases.remove(doc.id);
      } else {
        _aliases[doc.id] = alias;
      }
    });
    await _savePrefs();
  }

  Future<void> _setArchived(DtsDocument doc, bool archived) async {
    setState(() {
      if (archived) {
        _archivedDocIds.add(doc.id);
      } else {
        _archivedDocIds.remove(doc.id);
      }
    });
    await _savePrefs();
  }

  Future<void> _revealPin(DtsDocument doc) async {
    final pin = doc.trackingPin?.trim() ?? '';
    if (pin.isEmpty) return;
    final input = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reveal PIN'),
          content: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Enter tracking PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(input.text.trim() == pin),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
    if (verified == true) {
      setState(() => _revealedPinDocIds.add(doc.id));
    } else if (verified == false && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN did not match.')));
    }
  }

  void _open(DtsDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DtsDocumentDetailScreen(docId: doc.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = baseTheme.colorScheme;
    final user = _user;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('My Documents'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: scheme.onSurface,
          actions: [
            IconButton(
              tooltip: _showArchived ? 'Hide archived' : 'Show archived',
              onPressed: () => setState(() => _showArchived = !_showArchived),
              icon: Icon(
                _showArchived
                    ? Icons.inventory_2_outlined
                    : Icons.inventory_2_rounded,
              ),
            ),
          ],
        ),
        body: user == null
            ? const Center(child: Text('Please sign in to continue.'))
            : _loadingPrefs
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<DtsDocument>>(
                stream: DtsRepository().watchMyDocuments(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!
                      .where(
                        (doc) =>
                            _showArchived == _archivedDocIds.contains(doc.id),
                      )
                      .toList();
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        _showArchived
                            ? 'No archived documents.'
                            : 'No documents yet.',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final alias = _aliases[doc.id];
                      final pinRevealed = _revealedPinDocIds.contains(doc.id);
                      return _DocCard(
                        doc: doc,
                        alias: alias,
                        pinRevealed: pinRevealed,
                        onTap: () => _open(doc),
                        onRevealPin: () => _revealPin(doc),
                        onRename: () => _renameDoc(doc),
                        onArchiveToggle: () => _setArchived(
                          doc,
                          !_archivedDocIds.contains(doc.id),
                        ),
                        archived: _archivedDocIds.contains(doc.id),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onRevealPin,
    required this.onRename,
    required this.onArchiveToggle,
    required this.archived,
    this.alias,
    required this.pinRevealed,
  });

  final DtsDocument doc;
  final String? alias;
  final bool pinRevealed;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback onRevealPin;
  final VoidCallback onRename;
  final VoidCallback onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = scheme.outlineVariant.withValues(alpha: 0.5);
    final statusColor = DtsStatusHelper.color(context, doc.status);
    final fallbackTitle = doc.title.isNotEmpty
        ? doc.title
        : 'Untitled document';
    final title = (alias?.trim().isNotEmpty ?? false)
        ? alias!.trim()
        : fallbackTitle;
    final time = doc.updatedAt ?? doc.createdAt;
    final timeLabel = time != null ? _formatDate(time) : '';
    final hasPin =
        doc.trackingPin != null && doc.trackingPin!.trim().isNotEmpty;

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') onRename();
                            if (value == 'archive') onArchiveToggle();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'rename',
                              child: Text('Rename locally'),
                            ),
                            PopupMenuItem<String>(
                              value: 'archive',
                              child: Text(
                                archived ? 'Unarchive' : 'Archive locally',
                              ),
                            ),
                          ],
                        ),
                      ],
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
                    if (hasPin) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pinRevealed
                                  ? 'PIN: ${doc.trackingPin}'
                                  : 'PIN: ••••••',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (!pinRevealed)
                            TextButton(
                              onPressed: onRevealPin,
                              child: const Text('Reveal'),
                            ),
                        ],
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
