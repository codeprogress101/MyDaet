import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'daet_geo.dart';
import 'picked_location.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  final double? initialLat;
  final double? initialLng;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    final initial = LatLng(
      widget.initialLat ?? 14.1122,
      widget.initialLng ?? 122.9553,
    );
    _center = clampToDaet(initial);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Pick Location'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(PickedLocation(_center.latitude, _center.longitude));
              },
              child:
                  const Text('Use', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          ],
        ),
        body: FlutterMap(
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 16,
            cameraConstraint: CameraConstraint.contain(
              bounds: daetBounds(),
            ),
            onPositionChanged: (pos, hasGesture) {
              final c = pos.center;
              if (c == null) return;
              setState(() => _center = clampToDaet(c));
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mydaet.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _center,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin, size: 40),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () {
              if (!isWithinDaet(_center.latitude, _center.longitude)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pick a location within Daet, Camarines Norte.'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(
                PickedLocation(_center.latitude, _center.longitude),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.check),
            label: Text(
              'Use this location (${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)})',
            ),
          ),
        ),
      ),
    );
  }
}
