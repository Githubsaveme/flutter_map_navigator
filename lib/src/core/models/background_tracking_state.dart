import 'geo_location.dart';

/// State of the background tracking engine and foreground service.
class BackgroundTrackingState {
  final bool isRunning;
  final bool permissionGranted;
  final bool serviceRunning;
  final GeoLocation? lastUpdate;

  const BackgroundTrackingState({
    required this.isRunning,
    required this.permissionGranted,
    required this.serviceRunning,
    this.lastUpdate,
  });

  factory BackgroundTrackingState.fromMap(Map<dynamic, dynamic> map, [GeoLocation? lastLocation]) {
    return BackgroundTrackingState(
      isRunning: map['isRunning'] as bool? ?? false,
      permissionGranted: map['permissionGranted'] as bool? ?? false,
      serviceRunning: map['isRunning'] as bool? ?? false,
      lastUpdate: lastLocation,
    );
  }

  @override
  String toString() {
    return 'BackgroundTrackingState(isRunning: $isRunning, permissionGranted: $permissionGranted, serviceRunning: $serviceRunning, lastUpdate: $lastUpdate)';
  }
}
