import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'announcements_screen.dart';
import 'create_report_screen.dart';
import 'hotlines_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_stub_screen.dart';
import 'report_detail_screen.dart';
import '../shared/widgets/notification_bell.dart';
import '../shared/widgets/search_field.dart';
import '../../services/announcements_service.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  static const _quickActionsPrefsKey = 'resident_quick_actions_v1';

  static const _quickActions = [
    _QuickActionConfig(
      id: _QuickActionId.createReport,
      icon: Icons.add_circle_outline,
      title: 'Create Report',
      subtitle: 'Photo + Location',
    ),
    _QuickActionConfig(
      id: _QuickActionId.myReports,
      icon: Icons.list_alt_outlined,
      title: 'My Reports',
      subtitle: 'Track progress',
    ),
    _QuickActionConfig(
      id: _QuickActionId.announcements,
      icon: Icons.campaign_outlined,
      title: 'Announcements',
      subtitle: 'Advisories & Events',
    ),
    _QuickActionConfig(
      id: _QuickActionId.hotlines,
      icon: Icons.phone_in_talk_outlined,
      title: 'Hotlines',
      subtitle: 'Tap-to-call',
    ),
  ];

  late Set<_QuickActionId> _enabledQuickActions;

  @override
  void initState() {
    super.initState();
    _enabledQuickActions = _QuickActionId.values.toSet();
    _loadQuickActions();
  }

  Future<void> _loadQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_quickActionsPrefsKey);
    if (stored == null) return;
    if (stored.isEmpty) {
      if (!mounted) return;
      setState(() => _enabledQuickActions = <_QuickActionId>{});
      return;
    }

    final restored = <_QuickActionId>{};
    for (final raw in stored) {
      for (final id in _QuickActionId.values) {
        if (id.name == raw) {
          restored.add(id);
          break;
        }
      }
    }

    if (restored.isEmpty) return;
    if (!mounted) return;
    setState(() => _enabledQuickActions = restored);
  }

  Future<void> _saveQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _quickActionsPrefsKey,
      _enabledQuickActions.map((e) => e.name).toList(),
    );
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: _HomeSearchDelegate(rootContext: context),
    );
  }

  void _openQuickActionsEditor() {
    final baseTheme = Theme.of(context);
    final textTheme = baseTheme.textTheme;
    final accent = baseTheme.colorScheme.primary;
    final border = baseTheme.dividerColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: baseTheme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Edit Quick Actions',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final action in _quickActions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: border),
                          ),
                          child: SwitchListTile(
                            value: _enabledQuickActions.contains(action.id),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value) {
                                  _enabledQuickActions.add(action.id);
                                } else {
                                  _enabledQuickActions.remove(action.id);
                                }
                              });
                              setState(() {});
                              _saveQuickActions();
                            },
                            secondary: Icon(action.icon, color: accent),
                            title: Text(action.title),
                            subtitle: Text(action.subtitle),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleQuickActionTap(_QuickActionId id) {
    switch (id) {
      case _QuickActionId.createReport:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CreateReportScreen(),
          ),
        );
        break;
      case _QuickActionId.myReports:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MyReportsScreen(),
          ),
        );
        break;
      case _QuickActionId.announcements:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AnnouncementsScreen(),
          ),
        );
        break;
      case _QuickActionId.hotlines:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const HotlinesScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();
    final announcementsService = AnnouncementsService();
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = baseTheme.colorScheme.onSurface;
    final accent = baseTheme.colorScheme.primary;
    final border = baseTheme.dividerColor;
    final surface = baseTheme.colorScheme.surface;

    final enabledActions = _quickActions
        .where((action) => _enabledQuickActions.contains(action.id))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Theme(
          data: baseTheme.copyWith(textTheme: textTheme),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 30,
                    height: 30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MyDaet',
                    style: textTheme.titleMedium?.copyWith(
                      color: dark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  NotificationBellButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                    iconColor: dark,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                greeting,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search services, view updates, and submit reports.',
                style: textTheme.bodyMedium?.copyWith(
                  color: dark.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 16),
              SearchField(
                hintText: 'Search announcements, hotlines, reports...',
                readOnly: true,
                showCursor: false,
                onTap: _openSearch,
              ),
              const SizedBox(height: 18),
              _SectionTitle(
                title: 'Quick Actions',
                trailing: TextButton(
                  onPressed: _openQuickActionsEditor,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 10),
              if (enabledActions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                    color: surface,
                  ),
                  child: Text(
                    'No quick actions selected. Tap Edit to add.',
                    style: textTheme.bodySmall?.copyWith(
                      color: dark.withOpacity(0.6),
                    ),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.75,
                  children: [
                    for (final action in enabledActions)
                      _QuickActionTile(
                        icon: action.icon,
                        title: action.title,
                        subtitle: action.subtitle,
                        onTap: () => _handleQuickActionTap(action.id),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Discover Daet'),
              const SizedBox(height: 10),
              Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                color: surface,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    'assets/images/banner.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Latest Updates'),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: announcementsService.publishedAnnouncementsStream(
                  limit: 3,
                ),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      'Unable to load updates.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: dark.withOpacity(0.6),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Text(
                      'No announcements yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: dark.withOpacity(0.6),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < docs.length; i++) ...[
                        _UpdateCard(
                          title: (docs[i].data()['title'] ?? 'Untitled')
                              .toString(),
                          body: (docs[i].data()['body'] ?? '').toString(),
                          meta: _announcementMeta(docs[i].data()),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AnnouncementDetailScreen(
                                  announcementId: docs[i].id,
                                  data: docs[i].data(),
                                ),
                              ),
                            );
                          },
                        ),
                        if (i != docs.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _announcementMeta(Map<String, dynamic> data) {
    final meta = (data['meta'] ?? '').toString().trim();
    if (meta.isNotEmpty) return meta;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      final d = raw.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return 'Posted ${d.year}-$mm-$dd';
    }
    return 'Posted recently';
  }
}

enum _QuickActionId {
  createReport,
  myReports,
  announcements,
  hotlines,
}

class _QuickActionConfig {
  const _QuickActionConfig({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _QuickActionId id;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _HomeSearchDelegate extends SearchDelegate<void> {
  _HomeSearchDelegate({required this.rootContext})
      : _announcementsService = AnnouncementsService();

  final BuildContext rootContext;
  final AnnouncementsService _announcementsService;

  static const _hotlines = [
    ('MDRRMO', '0917 000 0000'),
    ('PSTMO / Traffic', '0918 000 0000'),
    ('PNP Daet', '0919 000 0000'),
    ('BFP Daet', '0920 000 0000'),
    ('RHU / Health', '0921 000 0000'),
  ];

  @override
  String get searchFieldLabel => 'Search announcements, hotlines, reports';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final baseTheme = Theme.of(rootContext);
    final border = baseTheme.dividerColor;
    final accent = baseTheme.colorScheme.primary;
    return baseTheme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseTheme.colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: accent, width: 1.3),
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return _buildBrowse(context);
    }
    return _buildResults(context);
  }

  Widget _buildBrowse(BuildContext context) {
    final accent = Theme.of(rootContext).colorScheme.primary;
    final border = Theme.of(rootContext).dividerColor;

    final targets = [
      _SearchTarget(
        icon: Icons.campaign_outlined,
        title: 'Announcements',
        subtitle: 'Browse announcements',
        onTap: () {
          close(context, null);
          Navigator.of(rootContext).push(
            MaterialPageRoute(
              builder: (_) => const AnnouncementsScreen(),
            ),
          );
        },
      ),
      _SearchTarget(
        icon: Icons.phone_in_talk_outlined,
        title: 'Hotlines',
        subtitle: 'Browse emergency hotlines',
        onTap: () {
          close(context, null);
          Navigator.of(rootContext).push(
            MaterialPageRoute(
              builder: (_) => const HotlinesScreen(),
            ),
          );
        },
      ),
      _SearchTarget(
        icon: Icons.list_alt_outlined,
        title: 'My Reports',
        subtitle: 'Browse your reports',
        onTap: () {
          close(context, null);
          Navigator.of(rootContext).push(
            MaterialPageRoute(
              builder: (_) => const MyReportsScreen(),
            ),
          );
        },
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchSectionHeader(title: 'Search in'),
        _SearchTargetList(
          targets: targets,
          accent: accent,
          border: border,
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return _buildBrowse(context);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchSectionHeader(title: 'Announcements'),
        _buildAnnouncementsResults(context, q),
        const SizedBox(height: 14),
        _SearchSectionHeader(title: 'My Reports'),
        _buildReportsResults(context, q),
        const SizedBox(height: 14),
        _SearchSectionHeader(title: 'Hotlines'),
        _buildHotlineResults(context, q),
      ],
    );
  }

  Widget _buildAnnouncementsResults(BuildContext context, String q) {
    final border = Theme.of(rootContext).dividerColor;
    final accent = Theme.of(rootContext).colorScheme.primary;
    final queryLower = q.toLowerCase();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _announcementsService.publishedAnnouncementsStream(limit: 25),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load announcements.',
            style: Theme.of(rootContext)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final matches = docs.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final body = (data['body'] ?? '').toString().toLowerCase();
          final meta = (data['meta'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString().toLowerCase();
          return title.contains(queryLower) ||
              body.contains(queryLower) ||
              meta.contains(queryLower) ||
              category.contains(queryLower);
        }).toList();

        if (matches.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchEmptyState(label: 'No matching announcements.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    close(context, null);
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(
                        builder: (_) => AnnouncementsScreen(initialQuery: q),
                      ),
                    );
                  },
                  child: const Text('View all announcements'),
                ),
              ),
            ],
          );
        }

        final targets = matches.take(3).map((doc) {
          final data = doc.data();
          final title = (data['title'] ?? 'Announcement').toString();
          final body = (data['body'] ?? '').toString();
          final meta = (data['meta'] ?? '').toString();
          final category = (data['category'] ?? '').toString();
          final subtitle =
              body.isNotEmpty ? body : meta.isNotEmpty ? meta : category;
          return _SearchTarget(
            icon: Icons.campaign_outlined,
            title: title,
            subtitle: subtitle.isEmpty ? 'Announcement' : subtitle,
            onTap: () {
              close(context, null);
              Navigator.of(rootContext).push(
                MaterialPageRoute(
                  builder: (_) => AnnouncementDetailScreen(
                    announcementId: doc.id,
                    data: data,
                  ),
                ),
              );
            },
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchTargetList(
              targets: targets,
              accent: accent,
              border: border,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  close(context, null);
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(
                      builder: (_) => AnnouncementsScreen(initialQuery: q),
                    ),
                  );
                },
                child: const Text('View all announcements'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportsResults(BuildContext context, String q) {
    final accent = Theme.of(rootContext).colorScheme.primary;
    final border = Theme.of(rootContext).dividerColor;
    final queryLower = q.toLowerCase();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchEmptyState(label: 'Sign in to search your reports.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                close(context, null);
                Navigator.of(rootContext).push(
                  MaterialPageRoute(
                    builder: (_) => const MyReportsScreen(),
                  ),
                );
              },
              child: const Text('Open My Reports'),
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('createdByUid', isEqualTo: user.uid)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load reports.',
            style: Theme.of(rootContext)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final matches = docs.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final status = (data['status'] ?? '').toString().toLowerCase();
          return title.contains(queryLower) || status.contains(queryLower);
        }).toList();

        if (matches.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchEmptyState(label: 'No matching reports.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    close(context, null);
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(
                        builder: (_) => MyReportsScreen(initialQuery: q),
                      ),
                    );
                  },
                  child: const Text('View all reports'),
                ),
              ),
            ],
          );
        }

        final targets = matches.take(3).map((doc) {
          final data = doc.data();
          final title = (data['title'] ?? 'Untitled report').toString();
          final status = (data['status'] ?? 'submitted').toString();
          return _SearchTarget(
            icon: Icons.assignment_outlined,
            title: title,
            subtitle: 'Status: $status',
            onTap: () {
              close(context, null);
              Navigator.of(rootContext).push(
                MaterialPageRoute(
                  builder: (_) => ReportDetailScreen(
                    reportId: doc.id,
                    initialData: data,
                  ),
                ),
              );
            },
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchTargetList(
              targets: targets,
              accent: accent,
              border: border,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  close(context, null);
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(
                      builder: (_) => MyReportsScreen(initialQuery: q),
                    ),
                  );
                },
                child: const Text('View all reports'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHotlineResults(BuildContext context, String q) {
    final accent = Theme.of(rootContext).colorScheme.primary;
    final border = Theme.of(rootContext).dividerColor;
    final queryLower = q.toLowerCase();
    final matches = _hotlines.where((item) {
      final name = item.$1.toLowerCase();
      final phone = item.$2.toLowerCase();
      return name.contains(queryLower) || phone.contains(queryLower);
    }).toList();

    if (matches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchEmptyState(label: 'No matching hotlines.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                close(context, null);
                Navigator.of(rootContext).push(
                  MaterialPageRoute(
                    builder: (_) => HotlinesScreen(initialQuery: q),
                  ),
                );
              },
              child: const Text('View all hotlines'),
            ),
          ),
        ],
      );
    }

    final targets = matches.take(3).map((item) {
      return _SearchTarget(
        icon: Icons.phone_in_talk_outlined,
        title: item.$1,
        subtitle: item.$2,
        onTap: () {
          close(context, null);
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(content: Text('Dial UI only: ${item.$2}')),
          );
        },
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchTargetList(
          targets: targets,
          accent: accent,
          border: border,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              close(context, null);
              Navigator.of(rootContext).push(
                MaterialPageRoute(
                  builder: (_) => HotlinesScreen(initialQuery: q),
                ),
              );
            },
            child: const Text('View all hotlines'),
          ),
        ),
      ],
    );
  }
}

class _SearchTarget {
  _SearchTarget({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
      ),
    );
  }
}

class _SearchTargetList extends StatelessWidget {
  const _SearchTargetList({
    required this.targets,
    required this.accent,
    required this.border,
  });

  final List<_SearchTarget> targets;
  final Color accent;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < targets.length; i++) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: border),
            ),
            child: ListTile(
              leading: Icon(targets[i].icon, color: accent),
              title: Text(
                targets[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                targets[i].subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: targets[i].onTap,
            ),
          ),
          if (i != targets.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final border = Theme.of(context).dividerColor;
    final surface = Theme.of(context).colorScheme.surface;
    final shadow = Colors.black.withOpacity(0.05);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          color: surface,
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.title,
    required this.body,
    required this.meta,
    this.onTap,
  });
  final String title;
  final String body;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child:
                    Icon(Icons.info_outline, color: Color(0xFFE46B2C), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.54),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.38),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
