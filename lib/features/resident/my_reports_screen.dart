import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/empty_state.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  void _retry() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE46B2C);
    final dark = Theme.of(context).colorScheme.onSurface;
    final user = FirebaseAuth.instance.currentUser;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: AppScaffold(
        title: 'My Reports',
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBarBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBarForegroundColor: dark,
        body: user == null
            ? const EmptyState(
                title: 'Not logged in',
                subtitle: 'Please sign in to view your reports.',
              )
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .where('createdByUid', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      title: 'Unable to load reports',
                      subtitle: '${snapshot.error}',
                      action: TextButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final isOffline = snapshot.data!.metadata.isFromCache;
                  final docs = snapshot.data!.docs.toList();
                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No reports yet',
                      subtitle: 'Create a report to get started.',
                    );
                  }

                  docs.sort((a, b) {
                    final ad = a.data() as Map<String, dynamic>;
                    final bd = b.data() as Map<String, dynamic>;
                    final at = ad['createdAt'] as Timestamp?;
                    final bt = bd['createdAt'] as Timestamp?;
                    final adt =
                        at?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bdt =
                        bt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bdt.compareTo(adt);
                  });

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      if (i == 0 && isOffline) {
                        return _OfflineBanner(textTheme: textTheme);
                      }

                      final dataIndex = isOffline ? i - 1 : i;
                      final data = docs[dataIndex].data() as Map<String, dynamic>;
                      final title =
                          (data['title'] as String?)?.trim().isNotEmpty == true
                              ? data['title'] as String
                              : 'Untitled report';
                      final status =
                          (data['status'] as String?)?.trim().isNotEmpty == true
                              ? data['status'] as String
                              : 'submitted';
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E0DA)),
                        ),
                        child: ListTile(
                          leading:
                              const Icon(Icons.assignment_outlined, color: accent),
                          title: Text(title),
                          subtitle: Text('Status: $status'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportDetailScreen(
                                  reportId: docs[dataIndex].id,
                                  initialData: data,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: docs.length + (isOffline ? 1 : 0),
                  );
                },
              ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E0DA)),
      ),
      child: ListTile(
        leading: const Icon(Icons.wifi_off, color: Color(0xFFE46B2C)),
        title: Text(
          'Offline',
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Showing cached reports.'),
      ),
    );
  }
}
