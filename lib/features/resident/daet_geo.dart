import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Approximate bounds for Daet, Camarines Norte.
// Adjust these if you have official boundary coordinates.
const double daetMinLat = 14.02;
const double daetMaxLat = 14.20;
const double daetMinLng = 122.86;
const double daetMaxLng = 123.05;

LatLngBounds daetBounds() {
  return LatLngBounds.unsafe(
    north: daetMaxLat,
    south: daetMinLat,
    east: daetMaxLng,
    west: daetMinLng,
  );
}

bool isWithinDaet(double lat, double lng) {
  return lat >= daetMinLat &&
      lat <= daetMaxLat &&
      lng >= daetMinLng &&
      lng <= daetMaxLng;
}

LatLng clampToDaet(LatLng point) {
  final lat = point.latitude.clamp(daetMinLat, daetMaxLat) as double;
  final lng = point.longitude.clamp(daetMinLng, daetMaxLng) as double;
  return LatLng(lat, lng);
}
