import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/section_title.dart';
import '../shared/widgets/search_field.dart';

class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _items = [
    ('MDRRMO', '0917 000 0000'),
    ('PSTMO / Traffic', '0918 000 0000'),
    ('PNP Daet', '0919 000 0000'),
    ('BFP Daet', '0920 000 0000'),
    ('RHU / Health', '0921 000 0000'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _query = initial;
      _searchController.text = initial;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;
    const accent = Color(0xFFE46B2C);

    final q = _query.trim().toLowerCase();
    final filteredItems = q.isEmpty
        ? _items
        : _items.where((e) {
            final name = e.$1.toLowerCase();
            final phone = e.$2.toLowerCase();
            return name.contains(q) || phone.contains(q);
          }).toList();

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Emergency Hotlines'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SearchField(
              controller: _searchController,
              hintText: 'Search hotlines...',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            const SectionTitle('Important Numbers'),
            const SizedBox(height: 12),
            if (filteredItems.isEmpty)
              Text(
                q.isEmpty
                    ? 'No hotlines available.'
                    : 'No hotlines found for "$q".',
                style: textTheme.bodyMedium?.copyWith(
                  color: dark.withValues(alpha: 0.6),
                ),
              )
            else
              for (var i = 0; i < filteredItems.length; i++) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: accent),
                    title: Text(filteredItems[i].$1),
                    subtitle: Text(filteredItems[i].$2),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dial UI only: ${filteredItems[i].$2}'),
                        ),
                      );
                    },
                  ),
                ),
                if (i != filteredItems.length - 1)
                  const SizedBox(height: 8),
              ],
            const SizedBox(height: 12),
            Text(
              'Next: add tap-to-call (url_launcher) + official hotline verification.',
              style: textTheme.bodySmall?.copyWith(
                color: dark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
