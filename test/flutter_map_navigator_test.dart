import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_navigator/flutter_map_navigator.dart';

void main() {
  group('GeoUtils Tests', () {
    test('Haversine distance calculation is accurate', () {
      const p1 = LatLng(30.9010, 75.8573); // Ludhiana
      const p2 = LatLng(30.7333, 76.7794); // Chandigarh

      final distMeters = GeoUtils.distanceMeters(p1, p2);
      final distKm = distMeters / 1000.0;

      expect(distKm, greaterThan(80.0));
      expect(distKm, lessThan(100.0));
    });

    test('Bearing calculation works correctly', () {
      const p1 = LatLng(0.0, 0.0);
      const p2 = LatLng(1.0, 0.0); // Due North

      final bearing = GeoUtils.bearingDegrees(p1, p2);
      expect(bearing, closeTo(0.0, 0.1));
    });

    test('Heading interpolation handles 360-degree wrap-around', () {
      final heading = GeoUtils.lerpHeading(350.0, 10.0, 0.5);
      expect(heading, closeTo(0.0, 0.1));
    });

    test('Coordinate validation filters invalid lat/lng values', () {
      expect(GeoUtils.isValidCoordinate(30.0, 75.0), isTrue);
      expect(GeoUtils.isValidCoordinate(95.0, 75.0), isFalse);
      expect(GeoUtils.isValidCoordinate(double.nan, 75.0), isFalse);
    });
  });

  group('OffRouteDetector Tests', () {
    test('OffRouteDetector triggers after consecutive off-route fixes', () {
      final detector = OffRouteDetector(
        config: const OffRouteConfig(
          offRouteDistanceMeters: 30.0,
          offRouteConfirmationCount: 2,
        ),
      );

      const route = RouteResult(
        id: 'test_route',
        geometry: [
          LatLng(30.0000, 75.0000),
          LatLng(30.0100, 75.0000),
        ],
        distanceMeters: 1000,
        durationSeconds: 100,
        steps: [],
      );

      final offRouteLoc = GeoLocation(
        latitude: 30.0050,
        longitude: 75.0100, // ~1km off route
        accuracy: 5.0,
        timestamp: DateTime.now(),
      );

      expect(detector.evaluatePosition(offRouteLoc, route), isFalse); // Fix #1
      expect(detector.evaluatePosition(offRouteLoc, route), isTrue); // Fix #2 confirmed
    });
  });

  group('Kalman Filter Tests', () {
    test('GpsKalmanFilter smoothes noisy lat/long inputs', () {
      final filter = GpsKalmanFilter();
      final now = DateTime.now().millisecondsSinceEpoch;

      final f1 = filter.filter(30.0000, 75.0000, 10.0, now);
      final f2 = filter.filter(30.0050, 75.0000, 50.0, now + 1000); // Low accuracy spike

      expect(f1.latitude, equals(30.0000));
      expect(f2.latitude, lessThan(30.0050)); // Smoothed towards previous state
    });
  });
}
