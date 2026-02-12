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
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection("dts_documents");
    if (userContext != null && userContext.officeId != null) {
      query =
          query.where("currentOfficeId", isEqualTo: userContext.officeId);
    }
    return query.snapshots().map((s) => s.size);
  }

  Stream<int> _dtsInTransit(UserContext? userContext) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection("dts_documents");
    if (userContext != null && userContext.officeId != null) {
      query =
          query.where("currentOfficeId", isEqualTo: userContext.officeId);
    }
    query = query.where("status", isEqualTo: "IN_TRANSIT");
    return query.snapshots().map((s) => s.size);
  }

  Widget _animatedItem(int index, Widget child) {
    if (_reduceMotion) return child;
    final start = (index * 0.18).clamp(0.0, 0.9) as double;
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
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.assignment_ind),
                            title: const Text("Assigned (open)"),
                            trailing: Text(
                              "$v",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.folder),
                            title: const Text("Documents"),
                            trailing: Text(
                              "$v",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.local_shipping),
                            title: const Text("In transit"),
                            trailing: Text(
                              "$v",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
