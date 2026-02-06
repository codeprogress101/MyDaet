import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive/responsive.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ExploreItem(Icons.map_outlined, 'Tourism', 'Places to go, events', '/explore'),
      _ExploreItem(Icons.groups_outlined, 'Barangay Directory', 'Officials, contacts', '/explore'),
      _ExploreItem(Icons.call_outlined, 'Emergency', 'Hotlines and safety info', '/explore'),
      _ExploreItem(Icons.delete_outline, 'Waste Management', 'Schedules (soon)', '/explore'),
      _ExploreItem(Icons.report_problem_outlined, 'Report an Issue', 'Submit a concern', '/reports'),
    ];

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return ConstrainedPage(child: _ExploreCard(item: item));
        },
      ),
    );
  }
}

class _ExploreItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  _ExploreItem(this.icon, this.title, this.subtitle, this.route);
}

class _ExploreCard extends StatelessWidget {
  final _ExploreItem item;
  const _ExploreCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go(item.route),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
