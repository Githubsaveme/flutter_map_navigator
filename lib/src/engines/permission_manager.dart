import 'package:location/location.dart' as loc_pkg;
import '../core/models/permission_status.dart';
import '../core/logging/logger.dart';

/// Subsystem responsible for location permissions and location service enabling using package:location.
class PermissionManager {
  final loc_pkg.Location _location = loc_pkg.Location();

  /// Checks if device location service GPS is enabled.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _location.serviceEnabled();
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error checking location service status', e);
      return false;
    }
  }

  /// Gets current location permission status.
  Future<LocationPermissionStatus> locationStatus() async {
    try {
      final status = await _location.hasPermission();
      return _mapPermissionStatus(status);
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error checking location permission', e);
      return LocationPermissionStatus.unknown;
    }
  }

  /// Checks location service & requests foreground location permission using package:location.
  Future<LocationPermissionStatus> requestLocation() async {
    try {
      RouteEngineLogger.info('PermissionManager', 'Checking location service and permission via package:location');

      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          RouteEngineLogger.warning('PermissionManager', 'User declined enabling location services.');
          return LocationPermissionStatus.denied;
        }
      }

      loc_pkg.PermissionStatus permission = await _location.hasPermission();
      if (permission == loc_pkg.PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }

      return _mapPermissionStatus(permission);
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error requesting location permission', e);
      return LocationPermissionStatus.unknown;
    }
  }

  /// Requests background location permission using package:location.
  Future<LocationPermissionStatus> requestBackgroundLocation() async {
    try {
      RouteEngineLogger.info('PermissionManager', 'Requesting background location via package:location');
      await _location.enableBackgroundMode(enable: true);
      final status = await _location.hasPermission();
      return _mapPermissionStatus(status);
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error requesting background location', e);
      return LocationPermissionStatus.unknown;
    }
  }

  /// Opens application system settings.
  Future<bool> openSettings() async {
    try {
      return await _location.requestService();
    } catch (e) {
      RouteEngineLogger.error('PermissionManager', 'Error opening system settings', e);
      return false;
    }
  }

  LocationPermissionStatus _mapPermissionStatus(loc_pkg.PermissionStatus status) {
    switch (status) {
      case loc_pkg.PermissionStatus.granted:
        return LocationPermissionStatus.foreground;
      case loc_pkg.PermissionStatus.grantedLimited:
        return LocationPermissionStatus.approximate;
      case loc_pkg.PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case loc_pkg.PermissionStatus.deniedForever:
        return LocationPermissionStatus.deniedForever;
    }
  }
}
