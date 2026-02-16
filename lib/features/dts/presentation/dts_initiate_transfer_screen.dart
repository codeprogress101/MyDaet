import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/office.dart';
import '../../../services/user_context_service.dart';
import '../../../services/permissions.dart';
import '../../shared/user_directory_service.dart';
import '../data/dts_repository.dart';
import '../domain/dts_document.dart';

class DtsInitiateTransferScreen extends StatefulWidget {
  const DtsInitiateTransferScreen({super.key, required this.document});

  final DtsDocument document;

  @override
  State<DtsInitiateTransferScreen> createState() =>
      _DtsInitiateTransferScreenState();
}

class _DtsInitiateTransferScreenState extends State<DtsInitiateTransferScreen> {
  final _repo = DtsRepository();
  final _userContextService = UserContextService();
  final _directoryService = UserDirectoryService();
  late final Future<UserContext?> _contextFuture;

  List<Office> _offices = [];
  bool _loadingOffices = true;
  String? _selectedOfficeId;
  UserDirectoryItem? _selectedRecipient;
  bool _saving = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
    _loadOffices();
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
      if (_selectedOfficeId == null && active.isNotEmpty) {
        final first = active.firstWhere(
          (o) => o.id != widget.document.currentOfficeId,
          orElse: () => active.first,
        );
        setState(() {
          _selectedOfficeId = first.id;
        });
      }
    } catch (e) {
      setState(() {
        _offices = [];
        _loadingOffices = false;
        _status = 'Failed to load offices: $e';
      });
    }
  }

  Future<void> _submit(UserContext userContext) async {
    if (_saving) return;
    if (_selectedOfficeId == null) {
      setState(() => _status = 'Select a destination office.');
      return;
    }
    final selectedOffice = _offices.where(
      (office) => office.id == _selectedOfficeId,
    );
    final selectedOfficeName = selectedOffice.isEmpty
        ? null
        : selectedOffice.first.name;

    setState(() {
      _saving = true;
      _status = 'Initiating transfer...';
    });

    try {
      await _repo.initiateTransfer(
        docId: widget.document.id,
        fromOfficeId: widget.document.currentOfficeId,
        toOfficeId: _selectedOfficeId!,
        toOfficeName: selectedOfficeName,
        toUid: _selectedRecipient?.uid,
        previousStatus: widget.document.status,
        actorUid: userContext.uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final message = e is DtsQueuedActionException
            ? e.message
            : 'Failed: $e';
        setState(() => _status = message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final userContext = snapshot.data;
          if (userContext == null || !userContext.isStaff) {
            return const Scaffold(body: Center(child: Text('Not authorized.')));
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Initiate Transfer'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: scheme.onSurface,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Transfer ${widget.document.trackingNo}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingOffices)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOfficeId,
                    items: _offices
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.id,
                            child: Text(o.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() {
                              _selectedOfficeId = v;
                              _selectedRecipient = null;
                            });
                          },
                    decoration: InputDecoration(
                      labelText: 'Destination office',
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
                if (_selectedOfficeId != null)
                  StreamBuilder<List<UserDirectoryItem>>(
                    stream: _directoryService.watchAssignableUsers(
                      officeId: _selectedOfficeId,
                      roles: const ['moderator', 'office_admin'],
                    ),
                    builder: (context, snap) {
                      final users = snap.data ?? const <UserDirectoryItem>[];
                      if (users.isEmpty) {
                        return Text(
                          'No recipients available for selected office.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedRecipient?.uid,
                        items: users
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.uid,
                                child: Text(
                                  u.displayName.isNotEmpty
                                      ? u.displayName
                                      : u.email,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedRecipient = users.firstWhere(
                                    (u) => u.uid == v,
                                  );
                                });
                              },
                        decoration: InputDecoration(
                          labelText: 'Recipient (optional)',
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
                      );
                    },
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _submit(userContext),
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
                        : const Text('Send to office'),
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
