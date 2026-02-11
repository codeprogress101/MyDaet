import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_audit_log_screen.dart';
import 'admin_announcements_screen.dart';
import '../../services/permissions.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.userContext});

  final UserContext? userContext;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;
  bool _played = false;

  @override
  void initState() {
    super.initState();
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

  Stream<int> _count(String collection) {
    return FirebaseFirestore.instance.collection(collection).snapshots().map(
          (s) => s.size,
        );
  }

  Stream<int> _openReportsCount() {
    return FirebaseFirestore.instance
        .collection("reports")
        .where("status", whereIn: const ["submitted", "in_review", "assigned"])
        .snapshots()
        .map((s) => s.size);
  }

  Widget _statCard({
    required String label,
    required Stream<int> stream,
    required IconData icon,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final v = snap.data ?? 0;
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
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "$v",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    // NOTE: No Scaffold here (Shell already has AppBar + BottomNav)
    final canManageUsers = widget.userContext != null &&
        Permissions.canManageUsers(widget.userContext!);
    final auditScope = widget.userContext != null
        ? Permissions.auditLogScope(widget.userContext!)
        : AuditLogScope.none;
    final canViewAuditLogs = auditScope != AuditLogScope.none;
    final auditLabel =
        auditScope == AuditLogScope.office ? "Audit Logs (Office)" : "Audit Logs";

    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 16 * 2 - 12) / 2;

    var index = 0;
    final tiles = <Widget>[
      SizedBox(
        width: itemWidth,
        child: _statCard(
          label: "Reports",
          stream: _count("reports"),
          icon: Icons.receipt_long,
        ),
      ),
      if (canManageUsers)
        SizedBox(
          width: itemWidth,
          child: _statCard(
            label: "Users",
            stream: _count("users"),
            icon: Icons.people,
          ),
        ),
      SizedBox(
        width: itemWidth,
        child: _statCard(
          label: "Open Reports",
          stream: _openReportsCount(),
          icon: Icons.flag,
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles.map((w) => _animatedItem(index++, w)).toList(),
        ),
        const SizedBox(height: 16),
        if (canViewAuditLogs)
          _animatedItem(
            index++,
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(auditLabel),
                subtitle: Text(
                  auditScope == AuditLogScope.office
                      ? "View office-specific admin actions."
                      : "View recent admin actions.",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminAuditLogScreen(),
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
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
            "Tip: Use the Reports tab to assign and update statuses.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
        ),
      ],
    );
  }
}
