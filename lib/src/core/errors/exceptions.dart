/// Standard error codes for the FlutterRouteEngine SDK.
enum RouteErrorCode {
  permissionDenied,
  permissionDeniedForever,
  locationServiceDisabled,
  locationUnavailable,
  gpsTimeout,
  poorAccuracy,
  networkUnavailable,
  routingFailed,
  routeNotFound,
  reroutingFailed,
  geocodingFailed,
  mapInitializationFailed,
  tileLoadFailed,
  voiceUnavailable,
  backgroundTrackingUnavailable,
  unsupportedPlatform,
  invalidCoordinates,
  navigationFailed,
  unknown,
}

/// Custom exception thrown by the FlutterRouteEngine SDK.
class FlutterRouteException implements Exception {
  final RouteErrorCode code;
  final String message;
  final String? details;
  final Object? originalError;
  final StackTrace? stackTrace;
  final String? platform;

  FlutterRouteException({
    required this.code,
    required this.message,
    this.details,
    this.originalError,
    this.stackTrace,
    this.platform,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('[FlutterRouteEngine][${code.name.toUpperCase()}]');
    buffer.writeln(message);
    if (details != null) {
      buffer.writeln('Details: $details');
    }
    if (platform != null) {
      buffer.writeln('Platform: $platform');
    }
    buffer.writeln('Action: Check configuration, permissions, or network availability.');
    return buffer.toString();
  }
}
