import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportLocationScreen extends StatelessWidget {
  const ReportLocationScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.address,
  });

  final double lat;
  final double lng;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    final center = LatLng(lat, lng);
    final addressLabel = (address ?? '').trim();

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Report Location'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mydaet.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 42,
                            height: 42,
                            child: const Icon(
                              Icons.location_pin,
                              size: 42,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Card(
              elevation: 0,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (addressLabel.isNotEmpty)
                      Text(
                        addressLabel,
                        style: textTheme.bodyMedium?.copyWith(color: dark),
                      ),
                    if (addressLabel.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: dark.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openDirections(context, lat, lng),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.directions),
                        label: const Text('Get Directions'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openDirections(BuildContext context, double lat, double lng) async {
  final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
  final webUri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );

  try {
    final launchedGeo = await launchUrl(
      geoUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedGeo) return;
  } catch (_) {}

  try {
    final launchedWeb = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedWeb) return;
  } catch (_) {}

  try {
    final launchedWeb = await launchUrl(
      webUri,
      mode: LaunchMode.platformDefault,
    );
    if (launchedWeb) return;
  } catch (_) {}

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open maps.')),
    );
  }
}
