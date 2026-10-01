import 'package:latlong2/latlong.dart';

enum ManeuverType {
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  straight,
  uTurn,
  roundabout,
  depart,
  arrive,
  unknown;

  static ManeuverType fromString(String? type) {
    if (type == null) return ManeuverType.unknown;
    final lower = type.toLowerCase();
    if (lower.contains('slight left')) return ManeuverType.turnSlightLeft;
    if (lower.contains('slight right')) return ManeuverType.turnSlightRight;
    if (lower.contains('sharp left')) return ManeuverType.turnSharpLeft;
    if (lower.contains('sharp right')) return ManeuverType.turnSharpRight;
    if (lower.contains('left')) return ManeuverType.turnLeft;
    if (lower.contains('right')) return ManeuverType.turnRight;
    if (lower.contains('uturn') || lower.contains('u-turn')) return ManeuverType.uTurn;
    if (lower.contains('roundabout')) return ManeuverType.roundabout;
    if (lower.contains('depart') || lower.contains('start')) return ManeuverType.depart;
    if (lower.contains('arrive')) return ManeuverType.arrive;
    if (lower.contains('straight') || lower.contains('continue')) return ManeuverType.straight;
    return ManeuverType.unknown;
  }
}

/// Individual maneuver / turn instruction on a route.
class RouteStep {
  final String instruction;
  final ManeuverType maneuver;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> geometry;
  final String? roadName;

  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.geometry,
    this.roadName,
  });
}

/// Calculated route result from a routing provider.
class RouteResult {
  final String id;
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final List<LatLng> waypoints;
  final List<RouteResult> alternatives;

  const RouteResult({
    required this.id,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    this.waypoints = const [],
    this.alternatives = const [],
  });

  /// Formatted distance in km or meters.
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distanceMeters.round()} m';
    }
  }

  /// Formatted duration in hours & minutes.
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours}h ${remMinutes}m';
    } else {
      return '$minutes min';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'geometry': geometry.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'waypoints': waypoints.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList(),
    };
  }
}
