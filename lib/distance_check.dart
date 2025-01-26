import 'dart:math';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const degToRad = pi / 180.0;
num radians(num x) => x * degToRad;

// In meters
const _radiusOfEarth = 6371000;

// In square meters
const _radiusOfEarthSqr = _radiusOfEarth * _radiusOfEarth;

// Checks if p1 is within r meters of p2
bool isWithinRadiusMetersCompute((Position p1, Position p2, double r) v) => isWithinRadiusMeters(v.$1, v.$2, v.$3);

// Checks if p1 is within r meters of p2
bool isWithinRadiusMeters(Position p1, Position p2, double r) {
  //if (r > 1000.0) {
  return _haversineDistanceCheck(p1, p2, r);
  //} else {
  //return _equirectangularDistanceCheck(p1, p2, r);
  //}
}

bool _equirectangularDistanceCheck(Position p1, Position p2, double r) {
  // Calculate the difference in longitude, adjusting for the 180 deg wraparound
  var deltaLng = p2.lng - p1.lng;
  if (deltaLng > 180.0) deltaLng -= 360.0;
  if (deltaLng < -180.0) deltaLng += 360.0;

  final dx = radians(deltaLng) * cos(radians(p2.lat + p1.lat) / 2.0);
  final dy = radians(p2.lat - p1.lat);

  final rSqr = r * r;
  final distSqr = _radiusOfEarthSqr * (dx * dx + dy * dy);

  return distSqr <= rSqr;
}

bool _haversineDistanceCheck(Position p1, Position p2, double r) {
  final lat1 = radians(p1.lat);
  final lng1 = radians(p1.lng);
  final lat2 = radians(p2.lat);
  final lng2 = radians(p2.lng);

  final dLat = lat2 - lat1;
  final dLng = lng2 - lng1;

  final a = pow(sin(dLat / 2.0), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2.0), 2);
  final c = 2.0 * atan2(sqrt(a), sqrt(1 - a));

  return c * _radiusOfEarth <= r;
}
