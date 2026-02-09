import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/widgets/section_title.dart';

class HotlinesScreen extends StatelessWidget {
  const HotlinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('MDRRMO', '0917 000 0000'),
      ('PSTMO / Traffic', '0918 000 0000'),
      ('PNP Daet', '0919 000 0000'),
      ('BFP Daet', '0920 000 0000'),
      ('RHU / Health', '0921 000 0000'),
    ];

    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;
    const accent = Color(0xFFE46B2C);

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
            const SectionTitle('Important Numbers'),
            const SizedBox(height: 12),
            ...items.map((e) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: border),
                ),
                child: ListTile(
                  leading: const Icon(Icons.phone, color: accent),
                  title: Text(e.$1),
                  subtitle: Text(e.$2),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dial UI only: ${e.$2}')),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Next: add tap-to-call (url_launcher) + official hotline verification.',
              style: textTheme.bodySmall?.copyWith(
                color: dark.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
