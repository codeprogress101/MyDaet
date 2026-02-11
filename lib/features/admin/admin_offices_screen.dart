import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../shared/widgets/search_field.dart';

class AdminOfficesScreen extends StatefulWidget {
  const AdminOfficesScreen({super.key});

  @override
  State<AdminOfficesScreen> createState() => _AdminOfficesScreenState();
}

class _AdminOfficesScreenState extends State<AdminOfficesScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _query = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _db.collection('offices').orderBy('name').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddOfficeDialog() async {
    final controller = TextEditingController();
    bool isActive = true;
    String? errorText;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Office'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Office name',
                      errorText: errorText,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      if (saving) return;
                      await _createOffice(
                        controller: controller,
                        isActive: isActive,
                        setDialogState: setDialogState,
                        setError: (v) => errorText = v,
                        setSaving: (v) => saving = v,
                      );
                      if (!context.mounted) return;
                      if (!saving) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: isActive,
                    onChanged: saving
                        ? null
                        : (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          await _createOffice(
                            controller: controller,
                            isActive: isActive,
                            setDialogState: setDialogState,
                            setError: (v) => errorText = v,
                            setSaving: (v) => saving = v,
                          );
                          if (!context.mounted) return;
                          if (!saving) {
                            Navigator.of(context).pop();
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

  Future<void> _createOffice({
    required TextEditingController controller,
    required bool isActive,
    required StateSetter setDialogState,
    required void Function(String?) setError,
    required void Function(bool) setSaving,
  }) async {
    final name = controller.text.trim();
    if (name.isEmpty) {
      setDialogState(() => setError('Name is required.'));
      return;
    }

    setDialogState(() {
      setSaving(true);
      setError(null);
    });

    try {
      final id = _officeIdFromName(name);
      final ref = _db.collection('offices').doc(id);
      final existing = await ref.get();
      if (existing.exists) {
        setDialogState(() {
          setSaving(false);
          setError('Office already exists.');
        });
        return;
      }

      await ref.set({
        'name': name,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Office added.')),
      );
    } catch (e) {
      setDialogState(() {
        setSaving(false);
        setError('Failed to add office: $e');
      });
      return;
    }

    setDialogState(() => setSaving(false));
  }

  Future<void> _showEditOfficeDialog(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? {};
    final controller = TextEditingController(
      text: (data['name'] ?? doc.id).toString(),
    );
    bool isActive = data['isActive'] is bool ? data['isActive'] as bool : true;
    String? errorText;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Office'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Office name',
                      errorText: errorText,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: isActive,
                    onChanged: saving
                        ? null
                        : (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = controller.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() {
                              errorText = 'Name is required.';
                            });
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            errorText = null;
                          });

                          try {
                            await doc.reference.set(
                              {
                                'name': name,
                                'isActive': isActive,
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                              SetOptions(merge: true),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Office updated.')),
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              errorText = 'Failed to update office: $e';
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

  Future<void> _toggleActive(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool value,
  ) async {
    await doc.reference.set(
      {
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.colorScheme.onSurface;
    final border = theme.dividerColor;
    const accent = Color(0xFFE46B2C);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? docs
            : docs
                .where((d) {
                  final data = d.data();
                  final name = (data['name'] ?? d.id).toString().toLowerCase();
                  return name.contains(q);
                })
                .toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No offices found.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _showAddOfficeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Office'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: Text(
                    'Manage offices and activation status.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: dark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showAddOfficeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Office'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SearchField(
              controller: _searchController,
              hintText: 'Search offices...',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No offices match "$q".',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: dark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((doc) {
                final data = doc.data();
                final name = (data['name'] ?? doc.id).toString();
                final isActive =
                    data['isActive'] is bool ? data['isActive'] as bool : true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: border),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isActive
                              ? accent.withValues(alpha: 0.9)
                              : dark.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: Icon(Icons.edit_outlined,
                              color: dark.withValues(alpha: 0.75)),
                          onPressed: () => _showEditOfficeDialog(doc),
                        ),
                        Switch.adaptive(
                          value: isActive,
                          onChanged: (v) => _toggleActive(doc, v),
                        ),
                      ],
                    ),
                    onTap: () => _showEditOfficeDialog(doc),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

String _officeIdFromName(String name) {
  final lower = name.toLowerCase().trim();
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final cleaned =
      slug.replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return cleaned.isEmpty ? 'office' : cleaned;
}
