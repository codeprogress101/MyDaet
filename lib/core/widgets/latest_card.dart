import 'package:flutter/material.dart';

class LatestCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;

  const LatestCard({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(body, style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Text('View all announcements →', style: TextStyle(color: cs.primary)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
