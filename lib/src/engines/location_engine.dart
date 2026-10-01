import 'dart:async';
import 'package:flutter/services.dart';
import 'package:location/location.dart' as loc_pkg;
import 'package:geolocator/geolocator.dart';
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
    this.minimumAccuracyMeters = 100.0,
    this.maximumJumpMeters = 200.0,
    this.maximumSpeedKmh = 250.0,
    this.staleLocationSeconds = 15,
  });
}

/// Subsystem for location updates, validation, and Kalman filtering using package:location, geolocator & native streams.
class LocationEngine {
  static const MethodChannel _methodChannel = MethodChannel('com.flutter_map_navigator/methods');
  static const EventChannel _eventChannel = EventChannel('com.flutter_map_navigator/location_stream');

  final loc_pkg.Location _locationService = loc_pkg.Location();
  final LocationFilterConfig config;
  final StreamController<GeoLocation> _controller = StreamController<GeoLocation>.broadcast();
  final GpsKalmanFilter _kalmanFilter = GpsKalmanFilter();

  StreamSubscription? _locationSubscription;
  StreamSubscription? _nativeSubscription;
  GeoLocation? _lastValidLocation;

  LocationEngine({this.config = const LocationFilterConfig()}) {
    _startListening();
  }

  /// Stream of validated and Kalman-filtered GPS locations.
  Stream<GeoLocation> get stream => _controller.stream;

  /// Gets current location fix via package:location, geolocator, or native fallback.
  Future<GeoLocation> current() async {
    if (_lastValidLocation != null) return _lastValidLocation!;

    // 1. Try package:location
    try {
      final locData = await _locationService.getLocation();
      final loc = GeoLocation(
        latitude: locData.latitude,
        longitude: locData.longitude,
        accuracy: locData.accuracy ?? 0.0,
        altitude: locData.altitude ?? 0.0,
        speed: locData.speed ?? 0.0,
        heading: locData.heading ?? 0.0,
        timestamp: locData.time != null
            ? DateTime.fromMillisecondsSinceEpoch(locData.time!.toInt())
            : DateTime.now(),
        isMock: locData.isMock ?? false,
      );
      if (loc.isValid) {
        _lastValidLocation = loc;
        _controller.add(loc);
        return loc;
      }
    } catch (_) {}

    // 2. Try Geolocator
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final loc = GeoLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        speed: pos.speed,
        heading: pos.heading,
        timestamp: pos.timestamp,
        isMock: pos.isMocked,
      );

      if (loc.isValid) {
        _lastValidLocation = loc;
        _controller.add(loc);
        return loc;
      }
    } catch (_) {}

    // 3. Native Channel Fallback
    try {
      final map = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      if (map != null) {
        final loc = GeoLocation.fromMap(map);
        if (loc.isValid) {
          _lastValidLocation = loc;
          _controller.add(loc);
          return loc;
        }
      }
    } catch (_) {}

    if (_lastValidLocation != null) return _lastValidLocation!;

    throw FlutterRouteException(
      code: RouteErrorCode.locationUnavailable,
      message: 'Failed to retrieve current location fix.',
    );
  }

  void _startListening() {
    // 1. package:location Stream
    try {
      _locationService.changeSettings(
        accuracy: loc_pkg.LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 0,
      );

      _locationSubscription = _locationService.onLocationChanged.listen((locData) {
        final raw = GeoLocation(
          latitude: locData.latitude,
          longitude: locData.longitude,
          accuracy: locData.accuracy ?? 0.0,
          altitude: locData.altitude ?? 0.0,
          speed: locData.speed ?? 0.0,
          heading: locData.heading ?? 0.0,
          timestamp: locData.time != null
              ? DateTime.fromMillisecondsSinceEpoch(locData.time!.toInt())
              : DateTime.now(),
          isMock: locData.isMock ?? false,
        );

        final filtered = _processAndFilter(raw);
        if (filtered != null) {
          _lastValidLocation = filtered;
          _controller.add(filtered);
        }
      }, onError: (err) {
        RouteEngineLogger.warning('LocationEngine', 'Location package stream warning: $err');
      });
    } catch (e) {
      RouteEngineLogger.warning('LocationEngine', 'Location package setup warning: $e');
    }

    // 2. Native Channel Stream for background location service fixes
    try {
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
          RouteEngineLogger.debug('LocationEngine', 'Native location stream debug: $error');
        },
      );
    } catch (_) {}
  }

  GeoLocation? _processAndFilter(GeoLocation raw) {
    if (!raw.isValid) return null;

    final effectiveMinAccuracy = _lastValidLocation == null
        ? 1000.0
        : config.minimumAccuracyMeters;

    if (raw.accuracy > effectiveMinAccuracy && raw.accuracy > 0) {
      return null;
    }

    if (DateTime.now().difference(raw.timestamp).inSeconds > config.staleLocationSeconds) {
      return null;
    }

    if (_lastValidLocation != null) {
      final distMeters = raw.distanceTo(_lastValidLocation!);
      final elapsedSec = raw.timestamp.difference(_lastValidLocation!.timestamp).inMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        final calculatedSpeedKmh = (distMeters / elapsedSec) * 3.6;
        if (calculatedSpeedKmh > config.maximumSpeedKmh) {
          return null;
        }
      }

      if (elapsedSec < 2.0 && distMeters > config.maximumJumpMeters) {
        return null;
      }
    }

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
    _locationSubscription?.cancel();
    _nativeSubscription?.cancel();
    _controller.close();
  }
}
