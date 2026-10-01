import 'package:latlong2/latlong.dart';
import '../utils/geo_utils.dart';

/// Represents a validated geographical location fix from GPS/Location Providers.
class GeoLocation {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final double altitude; // meters
  final double speed; // meters per second
  final double heading; // degrees (0..360)
  final DateTime timestamp;
  final bool isMock;

  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0.0,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
    required this.timestamp,
    this.isMock = false,
  });

  /// Speed converted to kilometers per hour.
  double get speedKmh => speed * 3.6;

  LatLng toLatLng() => LatLng(latitude, longitude);

  double distanceTo(GeoLocation other) {
    return GeoUtils.distanceMeters(toLatLng(), other.toLatLng());
  }

  double bearingTo(GeoLocation other) {
    return GeoUtils.bearingDegrees(toLatLng(), other.toLatLng());
  }

  bool get isValid => GeoUtils.isValidCoordinate(latitude, longitude);

  factory GeoLocation.fromMap(Map<dynamic, dynamic> map) {
    return GeoLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt())
          : DateTime.now(),
      isMock: map['isMock'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isMock': isMock,
    };
  }

  @override
  String toString() {
    return 'GeoLocation(lat: ${latitude.toStringAsFixed(6)}, lng: ${longitude.toStringAsFixed(6)}, acc: ${accuracy.toStringAsFixed(1)}m, speed: ${speedKmh.toStringAsFixed(1)}km/h, heading: ${heading.toStringAsFixed(1)}°)';
  }
}
