import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/reports_service.dart';

class ReportsSmokeTestScreen extends StatefulWidget {
  const ReportsSmokeTestScreen({super.key});

  @override
  State<ReportsSmokeTestScreen> createState() => _ReportsSmokeTestScreenState();
}

class _ReportsSmokeTestScreenState extends State<ReportsSmokeTestScreen> {
  final _reportsService = ReportsService();

  String _statusMsg = 'Ready';
  String? _selectedReportId;
  String? _selectedModeratorUid;

  final List<String> _statusOptions = const [
    'submitted',
    'in_review',
    'assigned',
    'resolved',
    'rejected',
  ];
  String _selectedStatus = 'in_review';

  Future<void> _assign() async {
    if (_selectedReportId == null) {
      setState(() => _statusMsg = 'Select a report first.');
      return;
    }
    if (_selectedModeratorUid == null || _selectedModeratorUid!.isEmpty) {
      setState(() => _statusMsg = 'Select a moderator first.');
      return;
    }

    setState(() => _statusMsg = 'Assigning...');
    try {
      await _reportsService.assignReport(
        reportId: _selectedReportId!,
        moderatorUid: _selectedModeratorUid!,
      );
      setState(() => _statusMsg = '✅ Assigned.');
    } catch (e) {
      setState(() => _statusMsg = '❌ Assign failed: $e');
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedReportId == null) {
      setState(() => _statusMsg = 'Select a report first.');
      return;
    }

    setState(() => _statusMsg = 'Updating status...');
    try {
      await _reportsService.updateReportStatus(
        reportId: _selectedReportId!,
        status: _selectedStatus,
      );
      setState(() => _statusMsg = '✅ Status updated to $_selectedStatus');
    } catch (e) {
      setState(() => _statusMsg = '❌ Update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .limit(50)
        .snapshots();

    final modsStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['moderator', 'admin', 'super_admin'])
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports Smoke Test')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ✅ BOUNDED HEIGHT LIST (prevents overflow)
                    SizedBox(
                      height: 220,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: reportsStream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text('Reports error: ${snap.error}'),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snap.data!.docs;
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No reports found.\nCreate one in Firestore or via resident flow.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data() as Map<String, dynamic>;

                              final title =
                                  (data['title'] ?? 'Untitled').toString();
                              final status =
                                  (data['status'] ?? '').toString();
                              final createdByUid =
                                  (data['createdByUid'] ?? '').toString();
                              final assignedToUid =
                                  (data['assignedToUid'] ?? '').toString();

                              final selected = _selectedReportId == doc.id;

                              return Card(
                                child: ListTile(
                                  title: Text(title),
                                  subtitle: Text(
                                    'id: ${doc.id}\nstatus: $status\ncreatedByUid: $createdByUid\nassignedToUid: $assignedToUid',
                                  ),
                                  trailing:
                                      selected ? const Icon(Icons.check) : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedReportId = doc.id;
                                      _statusMsg =
                                          'Selected report: ${doc.id}';
                                    });
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text('Selected report: ${_selectedReportId ?? '(none)'}'),
                    const SizedBox(height: 8),

                    // ✅ Moderator dropdown
                    StreamBuilder<QuerySnapshot>(
                      stream: modsStream,
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final docs = snap.data!.docs;

                        final items = docs.map((d) {
                          final data = d.data() as Map<String, dynamic>;
                          final email = (data['email'] ?? '').toString();
                          final role = (data['role'] ?? '').toString();
                          final label = email.isNotEmpty
                              ? '$email ($role)'
                              : '${d.id} ($role)';

                          return DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();

                        final selectedExists = items.any(
                          (x) => x.value == _selectedModeratorUid,
                        );
                        if (!selectedExists) _selectedModeratorUid = null;

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedModeratorUid,
                          items: items,
                          onChanged: (v) =>
                              setState(() => _selectedModeratorUid = v),
                          decoration: const InputDecoration(
                            labelText:
                                'Assign to moderator/admin (by email)',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _assign,
                      child: const Text(
                        'Assign Report (admin/super_admin)',
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ✅ Status dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      items: _statusOptions
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedStatus = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Update status',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _updateStatus,
                      child: const Text(
                        'Update Status (assigned moderator or admin+)',
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(_statusMsg),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
