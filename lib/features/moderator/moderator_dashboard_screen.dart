import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_announcements_screen.dart';
import '../../services/user_context_service.dart';
import '../../services/permissions.dart';
import '../dts/presentation/dts_home_screen.dart';

class ModeratorDashboardScreen extends StatefulWidget {
  const ModeratorDashboardScreen({super.key});

  @override
  State<ModeratorDashboardScreen> createState() =>
      _ModeratorDashboardScreenState();
}

class _ModeratorDashboardScreenState extends State<ModeratorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;
  bool _played = false;
  final _userContextService = UserContextService();
  late final Future<UserContext?> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.maybeOf(context);
    final reduce =
        (mq?.disableAnimations ?? false) || (mq?.accessibleNavigation ?? false);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (_reduceMotion) {
        _controller.value = 1;
      } else if (!_played) {
        _controller.forward();
        _played = true;
      }
    } else if (!_reduceMotion && !_played) {
      _controller.forward();
      _played = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Stream<int> _myAssignedCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return Stream<int>.value(0);

    return FirebaseFirestore.instance
        .collection("reports")
        .where("assignedToUid", isEqualTo: uid)
        .snapshots()
        .map((s) {
          final open = s.docs.where((d) {
            final status = (d.data()["status"] ?? "").toString();
            return status == "assigned" ||
                status == "in_review" ||
                status == "submitted";
          });
          return open.length;
        });
  }

  Stream<int> _dtsOfficeCount(UserContext? userContext) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "dts_documents",
    );
    if (userContext != null && userContext.officeId != null) {
      query = query.where("currentOfficeId", isEqualTo: userContext.officeId);
    }
    return query.snapshots().map((s) => s.size);
  }

  Stream<int> _dtsInTransit(UserContext? userContext) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "dts_documents",
    );
    if (userContext != null && userContext.officeId != null) {
      query = query.where("currentOfficeId", isEqualTo: userContext.officeId);
    }
    query = query.where("status", isEqualTo: "IN_TRANSIT");
    return query.snapshots().map((s) => s.size);
  }

  Stream<int> _dtsOverdue(UserContext? userContext) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "dts_documents",
    );
    if (userContext != null && userContext.officeId != null) {
      query = query.where("currentOfficeId", isEqualTo: userContext.officeId);
    }
    return query.snapshots().map((s) {
      final nowUtc = DateTime.now().toUtc();
      var count = 0;
      for (final doc in s.docs) {
        final data = doc.data();
        final due = data["dueAt"];
        if (due is! Timestamp) continue;
        final status = (data["status"] ?? "").toString().toUpperCase();
        final isClosed = status == "RELEASED" || status == "ARCHIVED";
        if (!isClosed && due.toDate().toUtc().isBefore(nowUtc)) {
          count += 1;
        }
      }
      return count;
    });
  }

  Stream<List<_OfficeSlaAlert>> _dtsSlaAlerts(UserContext? userContext) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "dts_documents",
    );
    if (userContext != null && userContext.officeId != null) {
      query = query.where("currentOfficeId", isEqualTo: userContext.officeId);
    }
    return query.snapshots().map((s) {
      final nowUtc = DateTime.now().toUtc();
      final grouped = <String, _OfficeSlaAlert>{};
      for (final doc in s.docs) {
        final data = doc.data();
        final dueAt = data["dueAt"];
        if (dueAt is! Timestamp) continue;
        final dueDate = dueAt.toDate().toUtc();
        final status = (data["status"] ?? "").toString().toUpperCase();
        final isClosed = status == "RELEASED" || status == "ARCHIVED";
        if (isClosed || !dueDate.isBefore(nowUtc)) continue;
        final officeId = (data["currentOfficeId"] ?? "").toString();
        final officeName = (data["currentOfficeName"] ?? officeId).toString();
        final key = officeId.isNotEmpty ? officeId : officeName;
        final existing = grouped[key];
        if (existing == null) {
          grouped[key] = _OfficeSlaAlert(
            officeId: officeId,
            officeName: officeName,
            overdueCount: 1,
            oldestDueAt: dueDate,
          );
        } else {
          grouped[key] = _OfficeSlaAlert(
            officeId: existing.officeId,
            officeName: existing.officeName,
            overdueCount: existing.overdueCount + 1,
            oldestDueAt: dueDate.isBefore(existing.oldestDueAt)
                ? dueDate
                : existing.oldestDueAt,
          );
        }
      }
      final alerts = grouped.values.toList()
        ..sort((a, b) => b.overdueCount.compareTo(a.overdueCount));
      return alerts;
    });
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required int value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedItem(int index, Widget child) {
    if (_reduceMotion) return child;
    final start = ((index * 0.18).clamp(0.0, 0.9)).toDouble();
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var index = 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 16 * 2 - 12) / 2;

    return FutureBuilder<UserContext?>(
      future: _contextFuture,
      builder: (context, snap) {
        final ctx = snap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _animatedItem(
                    index++,
                    StreamBuilder<int>(
                      stream: _myAssignedCount(),
                      builder: (context, snap) {
                        final v = snap.data ?? 0;
                        return _metricCard(
                          icon: Icons.assignment_ind,
                          label: 'Assigned (open)',
                          value: v,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _animatedItem(
                    index++,
                    StreamBuilder<int>(
                      stream: _dtsOfficeCount(ctx),
                      builder: (context, snap) {
                        final v = snap.data ?? 0;
                        return _metricCard(
                          icon: Icons.folder,
                          label: 'Documents',
                          value: v,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _animatedItem(
                    index++,
                    StreamBuilder<int>(
                      stream: _dtsInTransit(ctx),
                      builder: (context, snap) {
                        final v = snap.data ?? 0;
                        return _metricCard(
                          icon: Icons.local_shipping,
                          label: 'In transit',
                          value: v,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _animatedItem(
                    index++,
                    StreamBuilder<int>(
                      stream: _dtsOverdue(ctx),
                      builder: (context, snap) {
                        final v = snap.data ?? 0;
                        return _metricCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'Overdue docs',
                          value: v,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _animatedItem(
              index++,
              StreamBuilder<List<_OfficeSlaAlert>>(
                stream: _dtsSlaAlerts(ctx),
                builder: (context, alertSnap) {
                  final alerts = alertSnap.data ?? const <_OfficeSlaAlert>[];
                  if (alerts.isEmpty) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DTS SLA Alerts",
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...alerts
                              .take(4)
                              .map(
                                (alert) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• ${alert.officeName}: ${alert.overdueCount} overdue',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _animatedItem(
              index++,
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text("Documents"),
                  subtitle: const Text("Track custody and transfers."),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DtsHomeScreen(showAppBar: true),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _animatedItem(
              index++,
              Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign),
                  title: const Text("Announcements"),
                  subtitle: const Text("Create and publish updates."),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminAnnouncementsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _animatedItem(
              index++,
              Text(
                "Use the Reports tab to update status of assigned reports.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfficeSlaAlert {
  const _OfficeSlaAlert({
    required this.officeId,
    required this.officeName,
    required this.overdueCount,
    required this.oldestDueAt,
  });

  final String officeId;
  final String officeName;
  final int overdueCount;
  final DateTime oldestDueAt;
}
