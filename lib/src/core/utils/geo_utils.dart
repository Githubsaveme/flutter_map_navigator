import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Geographical math and navigation utilities.
class GeoUtils {
  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates Haversine distance in meters between two LatLng points.
  static double distanceMeters(LatLng p1, LatLng p2) {
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(p1.latitude)) *
            cos(_toRadians(p2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Calculates initial bearing in degrees (0..360) from p1 to p2.
  static double bearingDegrees(LatLng p1, LatLng p2) {
    final lat1 = _toRadians(p1.latitude);
    final lat2 = _toRadians(p2.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    return (_toDegrees(radians) + 360) % 360;
  }

  /// Calculates the shortest distance in meters from point P to line segment AB.
  static double distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final nearest = nearestPointOnSegment(p, a, b);
    return distanceMeters(p, nearest);
  }

  /// Finds the closest point on segment AB to point P.
  static LatLng nearestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final l2 = distanceMeters(a, b);
    if (l2 == 0) return a;

    // Project point P onto line segment AB
    final t = max(0.0, min(1.0,
      ((p.latitude - a.latitude) * (b.latitude - a.latitude) +
       (p.longitude - a.longitude) * (b.longitude - a.longitude)) /
      (pow(b.latitude - a.latitude, 2) + pow(b.longitude - a.longitude, 2))
    ));

    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  /// Linearly interpolates between two LatLng positions.
  static LatLng lerpLatLng(LatLng start, LatLng end, double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * f,
      start.longitude + (end.longitude - start.longitude) * f,
    );
  }

  /// Interpolates smooth heading degrees taking 360-degree wrap-around into account.
  static double lerpHeading(double start, double end, double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    var diff = (end - start) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (start + diff * f + 360) % 360;
  }

  /// Validates geographical coordinates.
  static bool isValidCoordinate(double lat, double lng) {
    return !lat.isNaN && !lng.isNaN && lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  static double _toRadians(double degree) => degree * pi / 180.0;
  static double _toDegrees(double rad) => rad * 180.0 / pi;
}

/// Simple 1D Kalman Filter for smoothing GPS lat/long stream.
class GpsKalmanFilter {
  final double _qMetresPerSecond;
  double _variance = -1.0;
  double _lat = 0.0;
  double _lng = 0.0;
  int _lastTimestampMs = 0;

  GpsKalmanFilter({double processNoise = 3.0}) : _qMetresPerSecond = processNoise;

  LatLng filter(double lat, double lng, double accuracyMeters, int timestampMs) {
    if (_variance < 0) {
      _lastTimestampMs = timestampMs;
      _lat = lat;
      _lng = lng;
      _variance = accuracyMeters * accuracyMeters;
      return LatLng(lat, lng);
    }

    final durationMs = timestampMs - _lastTimestampMs;
    if (durationMs > 0) {
      _variance += (durationMs / 1000.0) * _qMetresPerSecond * _qMetresPerSecond;
      _lastTimestampMs = timestampMs;
    }

    final k = _variance / (_variance + accuracyMeters * accuracyMeters);
    _lat += k * (lat - _lat);
    _lng += k * (lng - _lng);
    _variance = (1.0 - k) * _variance;

    return LatLng(_lat, _lng);
  }

  void reset() {
    _variance = -1.0;
  }
}
