import 'dart:async';
import 'package:flutter/services.dart';
import '../core/models/geo_location.dart';
import '../core/utils/geo_utils.dart';
import '../core/errors/exceptions.dart';
import '../core/logging/logger.dart';

/// Configuration for GPS jump and noise filtering.
class LocationFilterConfig {
  final double minimumAccuracyMeters;
  final double maximumJumpMeters;
  final double maximumSpeedKmh;
  final int staleLocationSeconds;

  const LocationFilterConfig({
    this.minimumAccuracyMeters = 50.0,
    this.maximumJumpMeters = 150.0,
    this.maximumSpeedKmh = 250.0,
    this.staleLocationSeconds = 10,
  });
}

/// Subsystem for location updates, validation, and Kalman filtering.
class LocationEngine {
  static const MethodChannel _methodChannel = MethodChannel('com.flutter_map_navigator/methods');
  static const EventChannel _eventChannel = EventChannel('com.flutter_map_navigator/location_stream');

  final LocationFilterConfig config;
  final StreamController<GeoLocation> _controller = StreamController<GeoLocation>.broadcast();
  final GpsKalmanFilter _kalmanFilter = GpsKalmanFilter();

  StreamSubscription? _nativeSubscription;
  GeoLocation? _lastValidLocation;

  LocationEngine({this.config = const LocationFilterConfig()}) {
    _startListening();
  }

  /// Stream of validated and Kalman-filtered GPS locations.
  Stream<GeoLocation> get stream => _controller.stream;

  /// Gets the last known or single fix current location.
  Future<GeoLocation> current() async {
    try {
      final map = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      if (map != null) {
        final loc = GeoLocation.fromMap(map);
        if (loc.isValid) {
          _lastValidLocation = loc;
          return loc;
        }
      }
    } catch (e, stack) {
      throw FlutterRouteException(
        code: RouteErrorCode.locationUnavailable,
        message: 'Failed to retrieve current location fix.',
        originalError: e,
        stackTrace: stack,
      );
    }

    if (_lastValidLocation != null) return _lastValidLocation!;

    throw FlutterRouteException(
      code: RouteErrorCode.locationUnavailable,
      message: 'Location service returned empty or invalid data.',
    );
  }

  void _startListening() {
    _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          final raw = GeoLocation.fromMap(data);
          final filtered = _processAndFilter(raw);
          if (filtered != null) {
            _lastValidLocation = filtered;
            _controller.add(filtered);
          }
        }
      },
      onError: (error) {
        RouteEngineLogger.error('LocationEngine', 'Native location stream error', error);
      },
    );
  }

  GeoLocation? _processAndFilter(GeoLocation raw) {
    if (!raw.isValid) return null;

    // Filter by accuracy
    if (raw.accuracy > config.minimumAccuracyMeters && raw.accuracy > 0) {
      RouteEngineLogger.debug('LocationEngine', 'Discarded location due to low accuracy: ${raw.accuracy}m');
      return null;
    }

    // Filter stale points
    if (DateTime.now().difference(raw.timestamp).inSeconds > config.staleLocationSeconds) {
      RouteEngineLogger.debug('LocationEngine', 'Discarded stale location');
      return null;
    }

    if (_lastValidLocation != null) {
      // Check maximum speed threshold
      final distMeters = raw.distanceTo(_lastValidLocation!);
      final elapsedSec = raw.timestamp.difference(_lastValidLocation!.timestamp).inMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        final calculatedSpeedKmh = (distMeters / elapsedSec) * 3.6;
        if (calculatedSpeedKmh > config.maximumSpeedKmh) {
          RouteEngineLogger.warning('LocationEngine', 'Discarded unrealistic speed spike: ${calculatedSpeedKmh.toStringAsFixed(1)} km/h');
          return null;
        }
      }

      // Check maximum jump distance if timestamp difference is very small
      if (elapsedSec < 2.0 && distMeters > config.maximumJumpMeters) {
        RouteEngineLogger.warning('LocationEngine', 'Discarded sudden GPS jump: ${distMeters.toStringAsFixed(1)}m');
        return null;
      }
    }

    // Apply Kalman filter for smooth lat/lng estimation
    final smoothedLatLng = _kalmanFilter.filter(
      raw.latitude,
      raw.longitude,
      raw.accuracy > 0 ? raw.accuracy : 10.0,
      raw.timestamp.millisecondsSinceEpoch,
    );

    return GeoLocation(
      latitude: smoothedLatLng.latitude,
      longitude: smoothedLatLng.longitude,
      accuracy: raw.accuracy,
      altitude: raw.altitude,
      speed: raw.speed,
      heading: raw.heading,
      timestamp: raw.timestamp,
      isMock: raw.isMock,
    );
  }

  void dispose() {
    _nativeSubscription?.cancel();
    _controller.close();
  }
}
