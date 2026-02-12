import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/office.dart';
import '../../../services/user_context_service.dart';
import '../../../services/permissions.dart';
import '../data/dts_repository.dart';
import 'dts_document_detail_screen.dart';
import '../../shared/widgets/search_field.dart';

class DtsCreateDocumentScreen extends StatefulWidget {
  const DtsCreateDocumentScreen({super.key, required this.qrCode});

  final String qrCode;

  @override
  State<DtsCreateDocumentScreen> createState() => _DtsCreateDocumentScreenState();
}

class _DtsCreateDocumentScreenState extends State<DtsCreateDocumentScreen> {
  final _repo = DtsRepository();
  final _userContextService = UserContextService();
  final _title = TextEditingController();
  final _source = TextEditingController();
  final _officeController = TextEditingController();
  final _picker = ImagePicker();

  final _docTypes = const [
    'Request',
    'Certificate',
    'Permit',
    'Complaint',
    'Endorsement',
    'Other',
  ];

  final _confidentialities = const [
    'public',
    'internal',
    'confidential',
  ];

  String _docType = 'Request';
  String _confidentiality = 'public';
  DateTime? _dueAt;
  File? _coverPhoto;

  List<Office> _offices = [];
  bool _loadingOffices = true;
  String? _selectedOfficeId;
  String? _selectedOfficeName;
  bool _officeManuallySelected = false;

  bool _saving = false;
  String _status = '';

  late final Future<UserContext?> _contextFuture;
  UserContext? _userContext;
  bool _defaultOfficeApplied = false;

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent().then((ctx) {
      _userContext = ctx;
      _applyDefaultOfficeIfNeeded();
      return ctx;
    });
    _loadOffices();
  }

  @override
  void dispose() {
    _title.dispose();
    _source.dispose();
    _officeController.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    setState(() => _loadingOffices = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('offices')
          .orderBy('name')
          .get();
      final all = snap.docs.map((d) => Office.fromDoc(d)).toList();
      final active = all.where((o) => o.isActive).toList();
      setState(() {
        _offices = active;
        _loadingOffices = false;
      });
      _applyDefaultOfficeIfNeeded();
    } catch (e) {
      setState(() {
        _offices = [];
        _loadingOffices = false;
        _status = 'Failed to load offices: $e';
      });
    }
  }

  void _applyDefaultOfficeIfNeeded() {
    if (_defaultOfficeApplied) return;
    if (_officeManuallySelected) return;
    if (_offices.isEmpty) return;
    final contextUser = _userContext;
    if (contextUser == null) return;

    Office match;
    if (contextUser.officeId != null) {
      match = _offices.firstWhere(
        (o) => o.id == contextUser.officeId,
        orElse: () => _offices.first,
      );
    } else {
      match = _offices.first;
    }

    _defaultOfficeApplied = true;
    setState(() {
      _selectedOfficeId = match.id;
      _selectedOfficeName = match.name;
      _officeController.text = match.name;
    });
  }

  Future<void> _openOfficePicker() async {
    if (_loadingOffices || _offices.isEmpty) return;

    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final border = baseTheme.dividerColor;

    final selected = await showModalBottomSheet<Office>(
      context: context,
      isScrollControlled: true,
      backgroundColor: baseTheme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) {
        String query = '';
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                final filtered = query.trim().isEmpty
                    ? _offices
                    : _offices
                        .where(
                          (o) =>
                              _normalize(o.name).contains(_normalize(query)),
                        )
                        .toList();

                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      16 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Container(
                                height: 4,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Select office',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SearchField(
                                hintText: 'Search office',
                                onChanged: (value) => setModalState(() {
                                  query = value;
                                }),
                                prefixIcon: const Icon(Icons.search),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        if (filtered.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No offices found.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: baseTheme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverList.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final office = filtered[index];
                              final isSelected =
                                  office.id == _selectedOfficeId;
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: border),
                                ),
                                tileColor: isSelected
                                    ? baseTheme.colorScheme.primary
                                        .withValues(alpha: 0.08)
                                    : null,
                                title: Text(
                                  office.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color:
                                            baseTheme.colorScheme.primary,
                                      )
                                    : const Icon(Icons.circle_outlined,
                                        color: Colors.transparent),
                                onTap: () =>
                                    Navigator.of(context).pop(office),
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
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedOfficeId = selected.id;
        _selectedOfficeName = selected.name;
        _officeController.text = selected.name;
        _officeManuallySelected = true;
      });
    }
  }

  Future<void> _pickCoverPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _coverPhoto = File(picked.path));
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _dueAt = picked);
    }
  }

  Future<void> _save(UserContext userContext) async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _status = 'Title is required.');
      return;
    }
    if (_selectedOfficeId == null || _selectedOfficeId!.isEmpty) {
      setState(() => _status = 'Select an office.');
      return;
    }
    if (_coverPhoto == null) {
      setState(() => _status = 'Cover photo is required.');
      return;
    }

    setState(() {
      _saving = true;
      _status = 'Creating document...';
    });

    try {
      final result = await _repo.createDocument(
        qrCode: widget.qrCode,
        title: _title.text.trim(),
        docType: _docType,
        confidentiality: _confidentiality,
        currentOfficeId: _selectedOfficeId!,
        currentOfficeName: _selectedOfficeName ?? 'Office',
        sourceName: _source.text.trim().isEmpty ? null : _source.text.trim(),
        dueAt: _dueAt,
        userContext: userContext,
        submittedByUid: null,
      );

      setState(() => _status = 'Uploading cover photo...');
      final cover = await _repo.uploadCoverPhoto(
        docId: result.docId,
        file: _coverPhoto!,
      );
      await _repo.updateCoverPhoto(
        docId: result.docId,
        coverPhoto: cover,
        actorUid: userContext.uid,
      );

      if (!mounted) return;
      await _showSuccess(result);
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        setState(() {
          _status =
              'Permission denied. Ensure your account is active and has staff access.';
        });
      } else {
        setState(() => _status = 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSuccess(DtsCreateResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Document created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tracking No: ${result.trackingNo}'),
              const SizedBox(height: 6),
              Text('PIN: ${result.pin}'),
              const SizedBox(height: 12),
              const Text(
                'Write the tracking number and PIN on the acknowledgment stub.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        DtsDocumentDetailScreen(docId: result.docId),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.primary),
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.3),
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
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }
          final userContext = snapshot.data;
          if (userContext == null || !userContext.isStaff) {
            return const Scaffold(
              body: Center(child: Text('Not authorized.')),
            );
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Create Document'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: scheme.onSurface,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'QR Code: ${widget.qrCode}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  enabled: !_saving,
                  decoration:
                      _inputDecoration(context, 'Title', Icons.title),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _docType,
                  items: _docTypes
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _saving ? null : (v) => setState(() => _docType = v!),
                  decoration: _inputDecoration(
                    context,
                    'Document type',
                    Icons.description_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _source,
                  enabled: !_saving,
                  decoration: _inputDecoration(
                    context,
                    'Source (optional)',
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _confidentiality,
                  items: _confidentialities
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _confidentiality = v!),
                  decoration: _inputDecoration(
                    context,
                    'Confidentiality',
                    Icons.lock_outline,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingOffices)
                  const Center(child: CircularProgressIndicator())
                else if (_offices.isEmpty)
                  Text(
                    'No active offices found.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                else
                  TextField(
                    controller: _officeController,
                    readOnly: true,
                    showCursor: false,
                    onTap: _openOfficePicker,
                    decoration: _inputDecoration(
                      context,
                      'Office',
                      Icons.business_outlined,
                    ).copyWith(
                      suffixIcon: const Icon(Icons.expand_more),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDueDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _dueAt == null
                        ? 'Set due date (optional)'
                        : 'Due: ${_formatDate(_dueAt!)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _CoverPhotoPicker(
                  coverPhoto: _coverPhoto,
                  onPick: _saving ? null : _pickCoverPhoto,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(userContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text('Save Document'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CoverPhotoPicker extends StatelessWidget {
  const _CoverPhotoPicker({required this.coverPhoto, required this.onPick});

  final File? coverPhoto;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cover photo (QR + stamp visible)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              color: scheme.surface,
            ),
            child: coverPhoto == null
                ? Center(
                    child: Text(
                      'Tap to capture cover photo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      coverPhoto!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\\s+'), ' ').trim();
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
