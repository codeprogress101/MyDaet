import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/responsive.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/quick_tile.dart';
import '../../core/widgets/latest_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cols = Responsive.gridCount(width);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: ConstrainedPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marhay na aga, Daeteño!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'What would you like to do today?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),

                  // Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search for services',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SectionTitle(title: 'Quick Actions'),
                  const SizedBox(height: 10),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: width >= 600 ? 1.35 : 1.2,
                    children: [
                      QuickTile(
                        icon: Icons.place_outlined,
                        title: 'Explore',
                        subtitle: 'Directory & info',
                        onTap: () => context.go('/explore'),
                      ),
                      QuickTile(
                        icon: Icons.campaign_outlined,
                        title: 'Announcements',
                        subtitle: 'LGU updates',
                        onTap: () => context.go('/updates'),
                      ),
                      QuickTile(
                        icon: Icons.description_outlined,
                        title: 'My Reports',
                        subtitle: 'Track status',
                        onTap: () => context.go('/reports'),
                      ),
                      QuickTile(
                        icon: Icons.person_outline,
                        title: 'Account',
                        subtitle: 'Sign in & settings',
                        onTap: () => context.go('/account'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // CTA Card
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.volunteer_activism_outlined,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Help us improve Daet',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Report issues in your area and we’ll forward them to the right office.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: Responsive.isTablet(context) ? 240 : double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.send_outlined),
                                    label: const Text('Report an Issue'),
                                    onPressed: () => context.go('/reports'),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const SectionTitle(title: 'Latest'),
                  const SizedBox(height: 10),

                  LatestCard(
                    title: "Mayor’s Advisory",
                    body: "Check updated municipal advisories and schedules.",
                    onTap: () => context.go('/updates'),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'MyDaet v0.1',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
