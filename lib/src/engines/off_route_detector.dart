import 'dart:math';
import '../core/models/geo_location.dart';
import '../core/models/route.dart';
import '../core/utils/geo_utils.dart';
import '../core/logging/logger.dart';

class OffRouteConfig {
  final double offRouteDistanceMeters;
  final int offRouteConfirmationCount;
  final Duration cooldownDuration;

  const OffRouteConfig({
    this.offRouteDistanceMeters = 40.0,
    this.offRouteConfirmationCount = 3,
    this.cooldownDuration = const Duration(seconds: 10),
  });
}

/// Evaluates if the user has departed from the active route.
class OffRouteDetector {
  final OffRouteConfig config;
  int _consecutiveOffRouteFixes = 0;
  DateTime? _lastRerouteTimestamp;

  OffRouteDetector({this.config = const OffRouteConfig()});

  /// Evaluates current position against active route geometry.
  /// Returns true if off-route condition is verified and ready for rerouting.
  bool evaluatePosition(GeoLocation location, RouteResult route) {
    if (route.geometry.length < 2) return false;

    // Do not trigger reroute if in cooldown period
    if (_lastRerouteTimestamp != null &&
        DateTime.now().difference(_lastRerouteTimestamp!) < config.cooldownDuration) {
      return false;
    }

    final userLatLng = location.toLatLng();
    double minDistanceMeters = double.infinity;

    for (int i = 0; i < route.geometry.length - 1; i++) {
      final p1 = route.geometry[i];
      final p2 = route.geometry[i + 1];
      final dist = GeoUtils.distanceToSegmentMeters(userLatLng, p1, p2);
      minDistanceMeters = min(minDistanceMeters, dist);
    }

    // Dynamic threshold adjusts for low GPS accuracy
    final effectiveThreshold = max(config.offRouteDistanceMeters, location.accuracy * 1.2);

    if (minDistanceMeters > effectiveThreshold) {
      _consecutiveOffRouteFixes++;
      RouteEngineLogger.warning('OffRouteDetector', 'Off-route candidate #$_consecutiveOffRouteFixes: ${minDistanceMeters.toStringAsFixed(1)}m from route (threshold: ${effectiveThreshold.toStringAsFixed(1)}m)');

      if (_consecutiveOffRouteFixes >= config.offRouteConfirmationCount) {
        _consecutiveOffRouteFixes = 0;
        _lastRerouteTimestamp = DateTime.now();
        RouteEngineLogger.warning('OffRouteDetector', 'Off-route confirmed! Triggering automatic reroute.');
        return true;
      }
    } else {
      _consecutiveOffRouteFixes = 0;
    }

    return false;
  }

  void reset() {
    _consecutiveOffRouteFixes = 0;
    _lastRerouteTimestamp = null;
  }
}
