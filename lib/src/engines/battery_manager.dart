import 'location_engine.dart';
import '../core/logging/logger.dart';

enum TrackingMode { lowPower, balanced, navigation, highAccuracy }

/// Subsystem for tracking power profiles and battery optimization.
class BatteryManager {
  TrackingMode currentMode = TrackingMode.navigation;

  LocationFilterConfig getFilterConfigForMode(TrackingMode mode) {
    switch (mode) {
      case TrackingMode.lowPower:
        return const LocationFilterConfig(
          minimumAccuracyMeters: 100.0,
          maximumJumpMeters: 300.0,
          staleLocationSeconds: 30,
        );
      case TrackingMode.balanced:
        return const LocationFilterConfig(
          minimumAccuracyMeters: 75.0,
          maximumJumpMeters: 200.0,
          staleLocationSeconds: 15,
        );
      case TrackingMode.navigation:
      case TrackingMode.highAccuracy:
        return const LocationFilterConfig(
          minimumAccuracyMeters: 50.0,
          maximumJumpMeters: 150.0,
          staleLocationSeconds: 10,
        );
    }
  }

  void setTrackingMode(TrackingMode mode) {
    currentMode = mode;
    RouteEngineLogger.info('BatteryManager', 'Tracking mode set to: $mode');
  }
}
