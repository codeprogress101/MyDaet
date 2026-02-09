import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'announcements_screen.dart';
import 'create_report_screen.dart';
import 'hotlines_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_stub_screen.dart';
import '../shared/widgets/notification_bell.dart';
import '../../services/announcements_service.dart';

class ResidentHomeScreen extends StatelessWidget {
  const ResidentHomeScreen({super.key});

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
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search announcements, hotlines, reports...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: surface,
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
                onTap: () {},
              ),
              const SizedBox(height: 18),
              _SectionTitle(
                title: 'Quick Actions',
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _QuickActionTile(
                    icon: Icons.add_circle_outline,
                    title: 'Create Report',
                    subtitle: 'Photo + Location',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateReportScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.list_alt_outlined,
                    title: 'My Reports',
                    subtitle: 'Track progress',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.campaign_outlined,
                    title: 'Announcements',
                    subtitle: 'Advisories & Events',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AnnouncementsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'Hotlines',
                    subtitle: 'Tap-to-call',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HotlinesScreen(),
                        ),
                      );
                    },
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).colorScheme.surface,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFE46B2C)),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.54),
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
