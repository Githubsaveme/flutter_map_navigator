import 'package:flutter/services.dart';
import '../core/models/permission_status.dart';
import '../core/logging/logger.dart';

/// Subsystem responsible for location permissions across Android & iOS.
class PermissionManager {
  static const MethodChannel _channel = MethodChannel('com.flutter_map_navigator/methods');

  /// Gets current location permission status.
  Future<LocationPermissionStatus> locationStatus() async {
    try {
      final String? statusStr = await _channel.invokeMethod<String>('getLocationPermissionStatus');
      if (statusStr != null) {
        return LocationPermissionStatus.parse(statusStr);
      }
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error checking location status', e);
    }
    return LocationPermissionStatus.unknown;
  }

  /// Requests foreground location permission.
  Future<LocationPermissionStatus> requestLocation() async {
    try {
      RouteEngineLogger.info('PermissionManager', 'Requesting location permission');
      await _channel.invokeMethod('requestWhenInUseAuthorization');
      return await locationStatus();
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error requesting location permission', e);
      return LocationPermissionStatus.unknown;
    }
  }

  /// Requests background location permission.
  Future<LocationPermissionStatus> requestBackgroundLocation() async {
    try {
      RouteEngineLogger.info('PermissionManager', 'Requesting background location permission');
      await _channel.invokeMethod('requestAlwaysAuthorization');
      return await locationStatus();
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error requesting background permission', e);
      return LocationPermissionStatus.unknown;
    }
  }

  /// Opens application system settings.
  Future<bool> openSettings() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('openSettings');
      return success ?? false;
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error opening system settings', e);
      return false;
    }
  }
}
