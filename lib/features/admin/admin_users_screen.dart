import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/office.dart';
import '../../services/permissions.dart';
import '../../services/user_context_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;
  static const List<String> _defaultOffices = [
    "Mayor's Office",
    "Municipal Administrator's Office",
    "Municipal Information Office (MIO)",
    "Local School Board (LSB) / Scholarship Office",
    "Municipal Planning and Development Office (MPDO)",
    "Municipal Disaster Risk Reduction and Management Office (MDRRMO)",
    "Municipal Environment and Natural Resources Office (MENRO)",
    "Municipal Treasurer's Office",
    "Municipal Social Welfare and Development Office (MSWDO)",
    "Public Employment Service Office (PESO)",
    "Senior Citizens Affairs Office (OSCA)",
    "Persons with Disability Affairs Office (PDAO)",
    "Public Safety and Traffic Management Unit (PSTMU)",
    "Municipal Health Office (MHO)",
    "Municipal Legal Office",
    "Human Resource Management Office (HRMO)",
    "Municipal Assessor's Office",
    "Municipal Accounting Office",
    "Municipal Budget Office",
    "Municipal Engineering Office",
    "Business Permits and Licensing Office (BPLO)",
    "Municipal Tourism Office",
    "Municipal Agriculture Office",
    "General Services Office (GSO)",
  ];

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  Future<List<Office>> _loadOffices() async {
    final snap = await FirebaseFirestore.instance
        .collection('offices')
        .orderBy('name')
        .get();
    return snap.docs.map((d) => Office.fromDoc(d)).toList();
  }

  Future<void> _showEditDialog({
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) async {
    final data = doc.data() ?? <String, dynamic>{};
    final currentRole = AppRole.normalize(data['role']?.toString());
    if (currentRole == AppRole.superAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Super admin role cannot be edited.')),
        );
      }
      return;
    }

    List<Office> offices = const [];
    try {
      offices = await _loadOffices();
    } catch (_) {
      offices = const [];
    }
    if (!mounted) return;

    String selectedRole = currentRole;
    String? selectedOfficeId = _string(data['officeId']);
    String? selectedOfficeName = _string(data['officeName']);
    bool isActive = data['isActive'] is bool ? data['isActive'] as bool : true;
    String? errorText;

    Office? officeFor(String? officeId) {
      if (officeId == null) return null;
      try {
        return offices.firstWhere((o) => o.id == officeId);
      } catch (_) {
        return null;
      }
    }

    Future<void> addOffice(StateSetter setDialogState) async {
      final controller = TextEditingController();
      String? localError;
      bool saving = false;

      final newOfficeId = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setOfficeState) {
              return AlertDialog(
                title: const Text('Add Office'),
                content: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Office name',
                    errorText: localError,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async {
                    if (saving) return;
                    final name = controller.text.trim();
                    if (name.isEmpty) {
                      setOfficeState(() => localError = 'Name is required.');
                      return;
                    }
                    setOfficeState(() {
                      saving = true;
                      localError = null;
                    });
                    try {
                      final ref = await FirebaseFirestore.instance
                          .collection('offices')
                          .add({
                        'name': name,
                        'isActive': true,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(ref.id);
                    } catch (e) {
                      setOfficeState(() {
                        saving = false;
                        localError = 'Failed to create office: $e';
                      });
                    }
                  },
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final name = controller.text.trim();
                            if (name.isEmpty) {
                              setOfficeState(
                                  () => localError = 'Name is required.');
                              return;
                            }
                            setOfficeState(() {
                              saving = true;
                              localError = null;
                            });
                            try {
                              final ref = await FirebaseFirestore.instance
                                  .collection('offices')
                                  .add({
                                'name': name,
                                'isActive': true,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop(ref.id);
                            } catch (e) {
                              setOfficeState(() {
                                saving = false;
                                localError = 'Failed to create office: $e';
                              });
                            }
                          },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (newOfficeId == null || newOfficeId.isEmpty) return;

      try {
        offices = await _loadOffices();
      } catch (_) {}

      if (!mounted) return;

      final selectedOffice = officeFor(newOfficeId);
      setDialogState(() {
        selectedOfficeId = newOfficeId;
        selectedOfficeName =
            selectedOffice?.name ?? selectedOfficeName ?? 'Office';
        errorText = null;
      });
    }

    Future<void> seedDefaultOffices(StateSetter setDialogState) async {
      final existingNames = offices
          .map((o) => o.name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet();
      final missing = _defaultOffices
          .where((name) => !existingNames.contains(name.toLowerCase()))
          .toList();

      if (missing.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Default offices already exist.')),
          );
        }
        return;
      }

      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final name in missing) {
          final id = _officeIdFromName(name);
          final ref = FirebaseFirestore.instance.collection('offices').doc(id);
          batch.set(
            ref,
            {
              'name': name,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
        offices = await _loadOffices();

        if (!mounted) return;
        setDialogState(() {
          if (selectedOfficeId == null && offices.isNotEmpty) {
            selectedOfficeId = offices.first.id;
            selectedOfficeName = offices.first.name;
          }
          errorText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${missing.length} offices.')),
        );
      } catch (e) {
        setDialogState(() {
          errorText = 'Failed to seed offices: $e';
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final roleRequiresOffice =
                selectedRole == AppRole.officeAdmin ||
                    selectedRole == AppRole.moderator;

            final officeLabels = <String>[
              'Unassigned',
              ...offices.map(
                (o) => o.isActive ? o.name : '${o.name} (inactive)',
              ),
            ];
            final officeItems = <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Unassigned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...offices.map(
                (o) => DropdownMenuItem<String?>(
                  value: o.id,
                  child: Text(
                    o.isActive ? o.name : '${o.name} (inactive)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ];

            return AlertDialog(
              title: const Text('Edit User'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey('role-$selectedRole'),
                      initialValue: selectedRole,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: AppRole.resident,
                          child: Text('resident'),
                        ),
                        DropdownMenuItem(
                          value: AppRole.moderator,
                          child: Text('moderator'),
                        ),
                        DropdownMenuItem(
                          value: AppRole.officeAdmin,
                          child: Text('office_admin'),
                        ),
                        DropdownMenuItem(
                          value: AppRole.superAdmin,
                          child: Text('super_admin'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          selectedRole = v;
                          errorText = null;
                          if (selectedRole == AppRole.resident ||
                              selectedRole == AppRole.superAdmin) {
                            selectedOfficeId = null;
                            selectedOfficeName = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('office-$selectedOfficeId'),
                      initialValue: selectedOfficeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Office',
                        border: OutlineInputBorder(),
                      ),
                      selectedItemBuilder: (context) {
                        return officeLabels
                            .map(
                              (label) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList();
                      },
                      items: officeItems,
                      onChanged: (v) {
                        final office = officeFor(v);
                        setDialogState(() {
                          selectedOfficeId = v;
                          selectedOfficeName = office?.name;
                          errorText = null;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offices.isEmpty
                              ? 'No offices found. Add or seed to continue.'
                              : 'Need more options?',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton(
                      onPressed: () => addOffice(setDialogState),
                      child: const Text('Add Office'),
                    ),
                    TextButton(
                      onPressed: () => seedDefaultOffices(setDialogState),
                      child: const Text('Seed Defaults'),
                    ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: isActive,
                      onChanged: (v) =>
                          setDialogState(() => isActive = v),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    if (roleRequiresOffice &&
                        (selectedOfficeId == null ||
                            selectedOfficeId!.isEmpty)) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Office is required for office_admin or moderator roles.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final roleRequiresOffice =
                        selectedRole == AppRole.officeAdmin ||
                            selectedRole == AppRole.moderator;
                    if (roleRequiresOffice &&
                        (selectedOfficeId == null ||
                            selectedOfficeId!.isEmpty)) {
                      setDialogState(() {
                        errorText =
                            'Please assign an office for this role.';
                      });
                      return;
                    }

                    final office = officeFor(selectedOfficeId);
                    try {
                      await doc.reference.update({
                        'role': selectedRole,
                        'officeId': roleRequiresOffice
                            ? selectedOfficeId
                            : null,
                        'officeName': roleRequiresOffice
                            ? (office?.name ?? selectedOfficeName)
                            : null,
                        'isActive': isActive,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('User updated.')),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      setDialogState(() {
                        errorText = 'Update failed: $e';
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserContext?>(
      future: _contextFuture,
      builder: (context, contextSnap) {
        if (contextSnap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (contextSnap.hasError) {
          return Center(child: Text('Error: ${contextSnap.error}'));
        }

        final userContext = contextSnap.data;
        if (userContext == null || !Permissions.canManageUsers(userContext)) {
          return const Center(child: Text('Not authorized.'));
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('email')
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No users found.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data();
                final email = (data['email'] ?? '(no email)') as String;
                final displayName = (data['displayName'] ?? '').toString();
                final rawRole = (data['role'] ?? AppRole.resident).toString();
                final role = AppRole.normalize(rawRole);
                final officeId = _string(data['officeId']);
                final officeName = _string(data['officeName']);
                final isActive = data['isActive'] is bool
                    ? data['isActive'] as bool
                    : true;

                final title = displayName.isNotEmpty ? displayName : email;
                final officeLabel = officeName ?? officeId;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (role != AppRole.superAdmin)
                              IconButton(
                                tooltip: 'Edit user',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showEditDialog(doc: d),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _roleChip(role),
                            _activeChip(isActive),
                            if (officeLabel != null)
                              _metaChip(
                                'Office: $officeLabel',
                                Theme.of(context).dividerColor,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Email: $email',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'UID: ${d.id}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
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
  }
}

Widget _roleChip(String role) {
  final color = _roleColor(role);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      role,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _activeChip(bool isActive) {
  final color = isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
  final label = isActive ? 'Active' : 'Inactive';
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

Widget _metaChip(String label, Color border) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );
}

Color _roleColor(String role) {
  switch (role) {
    case AppRole.superAdmin:
      return const Color(0xFF1B5E20);
    case AppRole.officeAdmin:
      return const Color(0xFF1E3A8A);
    case AppRole.moderator:
      return const Color(0xFF6D4C41);
    case AppRole.resident:
    default:
      return const Color(0xFFE46B2C);
  }
}

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _officeIdFromName(String name) {
  final lower = name.toLowerCase().trim();
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final cleaned = slug.replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return cleaned.isEmpty ? 'office' : cleaned;
}
