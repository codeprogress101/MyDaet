import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/dts_repository.dart';

class DtsOpsHealthScreen extends StatefulWidget {
  const DtsOpsHealthScreen({super.key});

  @override
  State<DtsOpsHealthScreen> createState() => _DtsOpsHealthScreenState();
}

class _DtsOpsHealthScreenState extends State<DtsOpsHealthScreen> {
  final _repo = DtsRepository();
  bool _loading = true;
  String _error = '';
  DtsOpsHealthResult? _health;
  List<DtsOfflineConflict> _conflicts = const <DtsOfflineConflict>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _repo.flushOfflineQueue();
      final health = await _repo.fetchOpsHealth();
      final conflicts = await _repo.getOfflineConflicts();
      if (!mounted) return;
      setState(() {
        _health = health;
        _conflicts = conflicts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final scheme = baseTheme.colorScheme;
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ops Health'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: scheme.onSurface,
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(child: Text('Unable to load health checks.\n$_error'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_health != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backend Runtime',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Build: ${_health!.backendBuild}'),
                            Text('Node: ${_health!.runtimeNode}'),
                            Text('Server time: ${_health!.nowIso}'),
                            const SizedBox(height: 6),
                            Text(
                              _health!.driftDetected
                                  ? 'Deployment drift detected (expected build mismatch).'
                                  : 'No build drift detected.',
                              style: textTheme.bodySmall?.copyWith(
                                color: _health!.driftDetected
                                    ? Colors.orange
                                    : scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Callable Checks',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_health != null)
                    ..._health!.callableChecks.entries.map((entry) {
                      return Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            entry.value
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: entry.value ? Colors.green : Colors.red,
                          ),
                          title: Text(entry.key),
                          subtitle: Text(
                            entry.value
                                ? 'Reachable'
                                : 'Missing or unreachable',
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text(
                    'Offline Sync Conflicts',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_conflicts.isEmpty)
                    const Text('No offline conflicts recorded.')
                  else
                    ..._conflicts
                        .take(20)
                        .map(
                          (conflict) => Card(
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.report_problem_outlined,
                              ),
                              title: Text(conflict.action),
                              subtitle: Text(conflict.reason),
                            ),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}
