import 'dart:async';
import 'package:flutter/scheduler.dart';
import '../core/models/geo_location.dart';
import '../core/utils/geo_utils.dart';

enum CameraFollowMode { free, follow, navigation, heading, northUp }

/// Subsystem that animates user location smoothly at 60fps between GPS updates.
class TrackingEngine {
  CameraFollowMode cameraMode = CameraFollowMode.follow;
  Duration animationDuration = const Duration(milliseconds: 1000);

  final StreamController<GeoLocation> _animatedLocationController = StreamController<GeoLocation>.broadcast();
  Ticker? _ticker;

  GeoLocation? _startLocation;
  GeoLocation? _targetLocation;
  DateTime? _animationStartTime;

  GeoLocation? _currentInterpolatedLocation;

  TrackingEngine() {
    _startTicker();
  }

  Stream<GeoLocation> get animatedLocationStream => _animatedLocationController.stream;
  GeoLocation? get currentLocation => _currentInterpolatedLocation;

  void updateTargetLocation(GeoLocation newLocation) {
    if (_targetLocation == null) {
      _startLocation = newLocation;
      _targetLocation = newLocation;
      _currentInterpolatedLocation = newLocation;
      _animatedLocationController.add(newLocation);
      return;
    }

    _startLocation = _currentInterpolatedLocation ?? _targetLocation;
    _targetLocation = newLocation;
    _animationStartTime = DateTime.now();
  }

  void _startTicker() {
    _ticker = Ticker((elapsed) {
      if (_startLocation == null || _targetLocation == null || _animationStartTime == null) return;

      final elapsedMs = DateTime.now().difference(_animationStartTime!).inMilliseconds;
      final progress = (elapsedMs / animationDuration.inMilliseconds).clamp(0.0, 1.0);

      final interpolatedLatLng = GeoUtils.lerpLatLng(
        _startLocation!.toLatLng(),
        _targetLocation!.toLatLng(),
        progress,
      );

      final interpolatedHeading = GeoUtils.lerpHeading(
        _startLocation!.heading,
        _targetLocation!.heading,
        progress,
      );

      final interpolatedSpeed = _startLocation!.speed + (_targetLocation!.speed - _startLocation!.speed) * progress;

      final animatedFix = GeoLocation(
        latitude: interpolatedLatLng.latitude,
        longitude: interpolatedLatLng.longitude,
        accuracy: _targetLocation!.accuracy,
        altitude: _targetLocation!.altitude,
        speed: interpolatedSpeed,
        heading: interpolatedHeading,
        timestamp: DateTime.now(),
        isMock: _targetLocation!.isMock,
      );

      _currentInterpolatedLocation = animatedFix;
      _animatedLocationController.add(animatedFix);
    });
    _ticker?.start();
  }

  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _animatedLocationController.close();
  }
}
