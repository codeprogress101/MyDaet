import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/report_status.dart';
import '../shared/user_directory_service.dart';
import '../shared/report_location_screen.dart';
import '../../services/permissions.dart';
import '../../services/user_context_service.dart';

class AdminReportDetailScreen extends StatefulWidget {
  const AdminReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  String? _assigneeUid; // null = unassigned
  String _status = "submitted";
  bool _saving = false;
  bool _archiving = false;

  final _userDirectory = UserDirectoryService();
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;
  final _noteController = TextEditingController();
  final List<PlatformFile> _noteFiles = [];

  DocumentReference<Map<String, dynamic>> get _ref {
    if (widget.reportId.trim().isEmpty) {
      throw ArgumentError("reportId must not be empty");
    }
    return FirebaseFirestore.instance.collection("reports").doc(widget.reportId);
  }

  String _coerceStatusForSave(String status, {required bool hasAssignee}) {
    final normalized = ReportStatusHelper.normalize(status);
    if (!hasAssignee && normalized == "assigned") return "submitted";
    if (hasAssignee && normalized == "submitted") return "assigned";
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<String?> _lookupEmail(String uid) async {
    final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    final email = (data["email"] ?? "").toString().trim();
    return email.isEmpty ? null : email;
  }

  Future<void> _pickNoteFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );
    if (res == null) return;

    setState(() {
      _noteFiles.addAll(res.files.where((f) => f.path != null));
    });
  }

  Future<List<Map<String, dynamic>>> _uploadNoteAttachments(
    String reportId,
    String messageId,
  ) async {
    if (_noteFiles.isEmpty) return [];

    final List<Map<String, dynamic>> uploaded = [];
    for (final f in _noteFiles) {
      final path = f.path;
      if (path == null) continue;

      final file = File(path);
      final fileName = f.name;
      final storagePath = "report_notes/$reportId/$messageId/$fileName";
      final ref = FirebaseStorage.instance.ref(storagePath);

      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      uploaded.add({
        "name": fileName,
        "path": storagePath,
        "url": url,
        "size": f.size,
        "contentType": task.metadata?.contentType,
        "uploadedAt": Timestamp.now(),
      });
    }

    return uploaded;
  }

  Future<String> _currentRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "unknown";
    try {
      final token = await user.getIdTokenResult();
      final role = token.claims?["role"];
      return AppRole.normalize(role is String ? role : null);
    } catch (_) {}
    return "resident";
  }

  Future<void> _save({required bool canEdit}) async {
    if (!canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You don't have permission to edit.")),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final hasAssignee = _assigneeUid != null && _assigneeUid!.trim().isNotEmpty;
      final email = hasAssignee ? await _lookupEmail(_assigneeUid!.trim()) : null;
      final status = _coerceStatusForSave(_status, hasAssignee: hasAssignee);
      final user = FirebaseAuth.instance.currentUser;
      final role = await _currentRole();

      await _ref.set(
        {
          "assignedToUid": hasAssignee ? _assigneeUid!.trim() : null,
          "assignedToEmail": email,
          "status": status,
          "updatedAt": FieldValue.serverTimestamp(),
          "lastActionByUid": user?.uid,
          "lastActionByEmail": user?.email,
          "lastActionByName": user?.displayName,
          "lastActionByRole": role,
          "lastActionAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final noteText = _noteController.text.trim();
      final hasNote = noteText.isNotEmpty || _noteFiles.isNotEmpty;
      if (hasNote) {
        final messageRef = _ref.collection("messages").doc();
        final attachments =
            await _uploadNoteAttachments(widget.reportId, messageRef.id);

        await messageRef.set({
          "text": noteText,
          "attachments": attachments,
          "createdByUid": user?.uid,
          "createdByEmail": user?.email,
          "createdByName": user?.displayName,
          "createdByRole": role,
          "type": "status_note",
          "status": status,
          "createdAt": FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _noteController.clear();
            _noteFiles.clear();
          });
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    InputDecoration inputDecoration(String label) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
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
          borderSide: const BorderSide(color: accent, width: 1.3),
        ),
      );
    }

    return FutureBuilder<UserContext?>(
      future: _contextFuture,
      builder: (context, contextSnap) {
        if (contextSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (contextSnap.hasError) {
          return Scaffold(
            body: Center(child: Text("Error: ${contextSnap.error}")),
          );
        }

        final userContext = contextSnap.data;
        if (userContext == null) {
          return const Scaffold(
            body: Center(child: Text("Not logged in.")),
          );
        }

        return Theme(
          data: baseTheme.copyWith(textTheme: textTheme),
          child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Report Detail"),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _ref.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text("Error: ${snap.error}"));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.data!.exists) {
              return const Center(child: Text("Report not found."));
            }

            final data = snap.data!.data()!;
            final title = (data["title"] ?? "Untitled") as String;
            final desc = (data["description"] ?? "") as String;
            final category = (data["category"] ?? "").toString().trim();
            final contactNumber = (data["contactNumber"] ?? "").toString().trim();
            final createdAt = data["createdAt"] as Timestamp?;
            final createdAtLabel = createdAt != null
                ? _formatDateTime(createdAt.toDate())
                : "Unknown date";

            final location = data["location"] is Map
                ? Map<String, dynamic>.from(data["location"] as Map)
                : <String, dynamic>{};
            final address = (location["address"] ?? "").toString().trim();
            final lat = location["lat"];
            final lng = location["lng"];
            final hasCoords = lat is num && lng is num;
            final attachments = _parseAttachments(data["attachments"]);
            final imageAttachments = attachments.where(_isImage).toList();
            final fileAttachments = attachments.where((a) => !_isImage(a)).toList();

            final currentStatus =
                ReportStatusHelper.normalize(data["status"] as String?);
            final archived = data["archived"] == true;
            final assignedToRaw = (data["assignedToUid"] ?? "") as String;
            final assignedTo = assignedToRaw.trim().isEmpty ? null : assignedToRaw;
            final reportOfficeId = (data["officeId"] ?? "").toString().trim();
            final canEdit = Permissions.canEditReport(
              userContext,
              reportOfficeId:
                  reportOfficeId.isEmpty ? null : reportOfficeId,
              assignedToUid: assignedTo,
              currentUserUid: userContext.uid,
            );
            final officeFilterId =
                userContext.isOfficeAdmin ? userContext.officeId : null;
            final assignableRoles = userContext.isSuperAdmin
                ? const ["moderator", "office_admin", "super_admin", "admin"]
                : userContext.isOfficeAdmin
                    ? const ["moderator", "office_admin"]
                    : userContext.isModerator
                        ? const ["moderator"]
                        : const <String>[];
            final manualUserError = userContext.isOfficeAdmin &&
                    (userContext.officeId == null ||
                        userContext.officeId!.trim().isEmpty)
                ? "Office is required to load assignees."
                : null;

            // Keep local selections in sync (only if not manually changed yet)
            _status =
                ReportStatusHelper.normalize(_status.isEmpty ? currentStatus : _status);
            _assigneeUid ??= assignedTo;

            return StreamBuilder<List<UserDirectoryItem>>(
              stream: _userDirectory.watchAssignableUsers(
                officeId: officeFilterId,
                roles: assignableRoles,
              ),
              builder: (context, userSnap) {
                final userError = manualUserError ?? userSnap.error;
                final options = (userSnap.data ?? const <UserDirectoryItem>[])
                    .map(
                      (u) => _UserPick(
                        uid: u.uid,
                        label: _formatUserLabel(u),
                        email: u.email,
                      ),
                    )
                    .toList();

                final items = <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      "Unassigned",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...options.map(
                    (u) => DropdownMenuItem<String?>(
                      value: u.uid,
                      child: Text(
                        u.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ];

                final allowedValues = items.map((e) => e.value).toSet();
                final safeAssignee =
                    allowedValues.contains(_assigneeUid) ? _assigneeUid : null;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleLarge?.copyWith(
                              color: dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (category.isNotEmpty)
                                _chip(
                                  label: category,
                                  icon: Icons.category_outlined,
                                  color: Theme.of(context).colorScheme.surface,
                                  textColor: dark,
                                  borderColor: border,
                                ),
                              _chip(
                                label: _prettyStatus(currentStatus),
                                icon: Icons.circle,
                                iconColor: _statusColor(currentStatus),
                                color: _statusColor(currentStatus).withValues(alpha: 0.12),
                                textColor: dark,
                                borderColor:
                                    _statusColor(currentStatus).withValues(alpha: 0.25),
                              ),
                              if (archived)
                                _chip(
                                  label: "Archived",
                                  icon: Icons.archive_outlined,
                                  iconColor: dark,
                                  color: const Color(0xFFFFF4ED),
                                  textColor: dark,
                                  borderColor: border,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: dark),
                              const SizedBox(width: 6),
                              Text(
                                "Created: $createdAtLabel",
                                style: textTheme.bodySmall?.copyWith(
                                  color: dark.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!canEdit) ...[
                      const SizedBox(height: 12),
                      _card(
                        context,
                        child: Text(
                          "Read-only: you don't have permission to edit this report.",
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _sectionTitle(context, "Tracking"),
                    const SizedBox(height: 8),
                    _card(context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _etaRow(context, currentStatus, textTheme),
                          const SizedBox(height: 12),
                          _statusTimeline(context, currentStatus, textTheme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, "Description"),
                    const SizedBox(height: 8),
                    _card(context,
                      child: Text(
                        desc.trim().isEmpty ? "No description provided." : desc,
                        style: textTheme.bodyMedium?.copyWith(color: dark),
                      ),
                    ),
                    if (contactNumber.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionTitle(context, "Contact Number"),
                      const SizedBox(height: 8),
                      _card(context,
                        child: Text(
                          contactNumber,
                          style: textTheme.bodyMedium?.copyWith(color: dark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _sectionTitle(context, "Location"),
                    const SizedBox(height: 8),
                    if (hasCoords || address.isNotEmpty)
                      _card(context,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.location_on_outlined, color: accent),
                          title: Text(
                            address.isNotEmpty ? address : "Pinned location",
                            style: textTheme.bodyMedium?.copyWith(color: dark),
                          ),
                          subtitle: hasCoords
                              ? Text(
                                  "${lat.toDouble().toStringAsFixed(6)}, ${lng.toDouble().toStringAsFixed(6)}",
                                  style: textTheme.bodySmall?.copyWith(
                                    color: dark.withValues(alpha: 0.7),
                                  ),
                                )
                              : Text(
                                  "Coordinates not available",
                                  style: textTheme.bodySmall?.copyWith(
                                    color: dark.withValues(alpha: 0.7),
                                  ),
                                ),
                          trailing: hasCoords
                              ? Icon(Icons.directions_outlined, color: dark)
                              : null,
                          onTap: hasCoords
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ReportLocationScreen(
                                        lat: lat.toDouble(),
                                        lng: lng.toDouble(),
                                        address: address,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                      )
                    else
                      _card(context,
                        child: Text(
                          "Location not available.",
                          style: textTheme.bodyMedium?.copyWith(color: dark),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, "Attachments"),
                    const SizedBox(height: 8),
                    if (attachments.isEmpty)
                      _card(context,
                        child: Text(
                          "No attachments uploaded.",
                          style: textTheme.bodyMedium?.copyWith(color: dark),
                        ),
                      )
                    else ...[
                      if (imageAttachments.isNotEmpty) ...[
                        _card(context,
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
                                          _string(imageAttachments.first["url"]),
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
                                    final url = _string(item["url"]);
                                    return _imageTile(context, url);
                                  },
                                ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (fileAttachments.isNotEmpty)
                        _card(context,
                          child: Column(
                            children: fileAttachments
                                .map(
                                  (item) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.insert_drive_file_outlined),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _string(item["name"],
                                                fallback: "Attachment"),
                                            style: textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatBytes(_int(item["size"])),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: dark.withValues(alpha: 0.7),
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
                    _sectionTitle(context, "Assignment"),
                    const SizedBox(height: 8),
                    if (userError != null)
                      _card(context,
                        child: Text(
                          "Unable to load assignees: $userError",
                          style: textTheme.bodySmall?.copyWith(color: Colors.red),
                        ),
                      ),
                    _card(context,
                      child: DropdownButtonFormField<String?>(
                        initialValue: safeAssignee,
                        isExpanded: true,
                        decoration: inputDecoration("Assign to"),
                        items: items,
                        onChanged: canEdit
                            ? (v) => setState(() => _assigneeUid = v)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, "Status"),
                    const SizedBox(height: 8),
                    _card(context,
                      child: DropdownButtonFormField<String>(
                        initialValue: ReportStatusHelper.normalize(_status),
                        decoration: inputDecoration("Status"),
                        items: ReportStatusHelper.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(ReportStatusHelper.pretty(s)),
                              ),
                            )
                            .toList(),
                        onChanged: canEdit
                            ? (v) => setState(
                                  () => _status = v ?? "submitted",
                                )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(context, "Add Note"),
                    const SizedBox(height: 8),
                    _card(context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _noteController,
                            enabled: canEdit && !_saving,
                            maxLines: 3,
                            decoration: inputDecoration("Note"),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed:
                                canEdit && !_saving ? _pickNoteFiles : null,
                            icon: const Icon(Icons.attach_file, color: accent),
                            label: const Text("Add Attachment"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: dark,
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          if (_noteFiles.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ..._noteFiles.map(
                              (f) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.insert_drive_file_outlined),
                                title: Text(
                                  f.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_formatBytes(f.size)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _saving || !canEdit
                                      ? null
                                      : () => setState(() => _noteFiles.remove(f)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, "Status History"),
                    const SizedBox(height: 8),
                    _historySection(context, widget.reportId, textTheme),
                    const SizedBox(height: 16),
                    _sectionTitle(context, "Notes"),
                    const SizedBox(height: 8),
                    _notesSection(context, widget.reportId, textTheme),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _archiving || !canEdit
                                  ? null
                                  : () => _toggleArchive(
                                        archive: !archived,
                                        canEdit: canEdit,
                                      ),
                              icon: _archiving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accent,
                                      ),
                                    )
                                  : Icon(
                                      archived
                                          ? Icons.unarchive_outlined
                                          : Icons.archive_outlined,
                                      color: accent,
                                    ),
                              label: Text(
                                archived ? "Restore" : "Archive",
                                style: const TextStyle(color: accent),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accent,
                                side: BorderSide(color: border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _saving || !canEdit
                                  ? null
                                  : () => _save(canEdit: canEdit),
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: scheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _saving
                                  ? SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_saving ? "Saving..." : "Save"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
        );
      },
    );
  }

  Future<void> _toggleArchive({
    required bool archive,
    required bool canEdit,
  }) async {
    if (!canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You don't have permission to edit.")),
        );
      }
      return;
    }
    setState(() => _archiving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final role = await _currentRole();

      await _ref.set(
        {
          "archived": archive,
          "archivedAt": archive ? FieldValue.serverTimestamp() : FieldValue.delete(),
          "archivedByUid": archive ? user?.uid : FieldValue.delete(),
          "archivedByEmail": archive ? user?.email : FieldValue.delete(),
          "archivedByName": archive ? user?.displayName : FieldValue.delete(),
          "archivedByRole": archive ? role : FieldValue.delete(),
          "updatedAt": FieldValue.serverTimestamp(),
          "lastActionByUid": user?.uid,
          "lastActionByEmail": user?.email,
          "lastActionByName": user?.displayName,
          "lastActionByRole": role,
          "lastActionAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(archive ? "Report archived." : "Report restored.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Archive failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }
}

class _UserPick {
  final String uid;
  final String label;
  final String email;
  const _UserPick({required this.uid, required this.label, required this.email});
}

String _formatUserLabel(UserDirectoryItem user) {
  final name = user.displayName.trim();
  final email = user.email.trim();
  final office = (user.officeName ?? user.officeId ?? '').trim();
  final officeLabel = office.isNotEmpty ? ' • $office' : '';
  if (name.isNotEmpty && email.isNotEmpty) {
    return "$name • $email$officeLabel";
  }
  if (name.isNotEmpty) return name;
  if (email.isNotEmpty) return "$email$officeLabel";
  return user.uid;
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
                    color: color.withValues(alpha: 0.8),
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
                      isDone ? onSurface : onSurface.withValues(alpha: 0.54),
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

Color _statusColor(String status) {
  switch (status) {
    case "in_review":
      return const Color(0xFF3A7BD5);
    case "assigned":
      return const Color(0xFF5B7C99);
    case "resolved":
      return const Color(0xFF2E7D32);
    case "rejected":
      return const Color(0xFFC62828);
    case "submitted":
    default:
      return const Color(0xFFE46B2C);
  }
}

String _prettyStatus(String status) {
  return status.replaceAll("_", " ").trim();
}

String _formatDateTime(DateTime dt) {
  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  final m = months[dt.month - 1];
  final day = dt.day.toString().padLeft(2, "0");
  final year = dt.year.toString();
  final hour = dt.hour.toString().padLeft(2, "0");
  final minute = dt.minute.toString().padLeft(2, "0");
  return "$m $day, $year • $hour:$minute";
}

Widget _historySection(
  BuildContext context,
  String reportId,
  TextTheme textTheme,
) {
  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection("reports")
        .doc(reportId)
        .collection("history")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _card(
          context,
          child: Text(
            "Unable to load history.",
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
            "No history yet.",
            style: textTheme.bodyMedium,
          ),
        );
      }

      return Column(
        children: docs.map((doc) {
          final data = doc.data();
          final createdAt = data["createdAt"] as Timestamp?;
          final when = createdAt != null
              ? _formatDateTime(createdAt.toDate())
              : "Just now";
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
                              .withValues(alpha: 0.6),
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
  final type = (data["type"] ?? "").toString();
  switch (type) {
    case "created":
      return "Report created.";
    case "status_changed":
      final from = (data["fromStatus"] ?? "").toString();
      final to = (data["toStatus"] ?? "").toString();
      if (from.isEmpty || to.isEmpty) return "Status updated.";
      return "Status changed from ${_prettyStatus(from)} to ${_prettyStatus(to)}.";
    case "assignment_changed":
      final to = (data["toAssignedUid"] ?? "").toString();
      if (to.isEmpty) return "Report unassigned.";
      return "Report assigned.";
    case "archived":
      return "Report archived.";
    case "restored":
      return "Report restored.";
    default:
      return (data["message"] ?? "Report updated.").toString();
  }
}

Widget _notesSection(
  BuildContext context,
  String reportId,
  TextTheme textTheme,
) {
  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection("reports")
        .doc(reportId)
        .collection("messages")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _card(
          context,
          child: Text(
            "Unable to load notes.",
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
            "No notes yet.",
            style: textTheme.bodyMedium,
          ),
        );
      }

      return Column(
        children: docs.map((doc) {
          final data = doc.data();
          final text = _string(data["text"]);
          final attachments = _parseAttachments(data["attachments"]);
          final imageAttachments = attachments.where(_isImage).toList();
          final fileAttachments = attachments.where((a) => !_isImage(a)).toList();
          final createdAt = data["createdAt"] as Timestamp?;
          final when = createdAt != null
              ? _formatDateTime(createdAt.toDate())
              : "Just now";

          final authorName = _string(data["createdByName"]);
          final authorEmail = _string(data["createdByEmail"]);
          final authorRole = _string(data["createdByRole"], fallback: "staff");
          String author = '';
          if (authorName.isNotEmpty && authorEmail.isNotEmpty) {
            author = "$authorName • $authorEmail";
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
                      final url = _string(item["url"]);
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
                              _string(item["name"], fallback: "Attachment"),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatBytes(_int(item["size"])),
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
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
                        .withValues(alpha: 0.6),
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
  final contentType = _string(item["contentType"]).toLowerCase();
  if (contentType.startsWith("image/")) return true;
  final name = _string(item["name"]).toLowerCase();
  return name.endsWith(".png") ||
      name.endsWith(".jpg") ||
      name.endsWith(".jpeg") ||
      name.endsWith(".gif") ||
      name.endsWith(".webp");
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
                errorBuilder: (_, _, _) =>
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.broken_image, color: scheme.onSurface),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: scheme.onSurface,
                        ),
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
                icon: Icon(Icons.close, color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _string(dynamic value, {String fallback = ""}) {
  if (value == null) return fallback;
  final s = value.toString().trim();
  return s.isEmpty ? fallback : s;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String _formatBytes(int? bytes) {
  if (bytes == null) return "Unknown size";
  if (bytes < 1024) return "$bytes B";
  final kb = bytes / 1024;
  if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";
  final mb = kb / 1024;
  if (mb < 1024) return "${mb.toStringAsFixed(1)} MB";
  final gb = mb / 1024;
  return "${gb.toStringAsFixed(1)} GB";
}
