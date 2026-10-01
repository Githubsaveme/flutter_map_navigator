/// Describes the current location permission state.
enum LocationPermissionStatus {
  unknown,
  notDetermined,
  denied,
  deniedForever,
  restricted,
  foreground,
  background,
  precise,
  approximate;

  bool get isGranted =>
      this == LocationPermissionStatus.foreground ||
      this == LocationPermissionStatus.background ||
      this == LocationPermissionStatus.precise ||
      this == LocationPermissionStatus.approximate;

  bool get isBackgroundGranted => this == LocationPermissionStatus.background;

  static LocationPermissionStatus parse(String value) {
    switch (value) {
      case 'notDetermined':
        return LocationPermissionStatus.notDetermined;
      case 'denied':
        return LocationPermissionStatus.denied;
      case 'deniedForever':
        return LocationPermissionStatus.deniedForever;
      case 'restricted':
        return LocationPermissionStatus.restricted;
      case 'foreground':
        return LocationPermissionStatus.foreground;
      case 'background':
        return LocationPermissionStatus.background;
      case 'precise':
        return LocationPermissionStatus.precise;
      case 'approximate':
        return LocationPermissionStatus.approximate;
      default:
        return LocationPermissionStatus.unknown;
    }
  }
}
