import 'geo_location.dart';
import 'route.dart';

enum NavigationStatus {
  idle,
  calculating,
  ready,
  starting,
  navigating,
  rerouting,
  arrived,
  paused,
  stopped,
  error,
}

/// Comprehensive turn-by-turn navigation state stream model.
class NavigationState {
  final NavigationStatus status;
  final GeoLocation? currentLocation;
  final String currentRoad;
  final String nextRoad;
  final String currentInstruction;
  final String nextInstruction;
  final ManeuverType maneuver;
  final double distanceToNextManeuver; // meters
  final double distanceRemaining; // meters
  final double durationRemaining; // seconds
  final DateTime? eta;
  final double progress; // 0.0 to 1.0
  final bool isOffRoute;
  final bool isRerouting;
  final RouteResult? activeRoute;

  const NavigationState({
    required this.status,
    this.currentLocation,
    this.currentRoad = '',
    this.nextRoad = '',
    this.currentInstruction = '',
    this.nextInstruction = '',
    this.maneuver = ManeuverType.straight,
    this.distanceToNextManeuver = 0.0,
    this.distanceRemaining = 0.0,
    this.durationRemaining = 0.0,
    this.eta,
    this.progress = 0.0,
    this.isOffRoute = false,
    this.isRerouting = false,
    this.activeRoute,
  });

  factory NavigationState.initial() {
    return const NavigationState(
      status: NavigationStatus.idle,
    );
  }

  NavigationState copyWith({
    NavigationStatus? status,
    GeoLocation? currentLocation,
    String? currentRoad,
    String? nextRoad,
    String? currentInstruction,
    String? nextInstruction,
    ManeuverType? maneuver,
    double? distanceToNextManeuver,
    double? distanceRemaining,
    double? durationRemaining,
    DateTime? eta,
    double? progress,
    bool? isOffRoute,
    bool? isRerouting,
    RouteResult? activeRoute,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      currentRoad: currentRoad ?? this.currentRoad,
      nextRoad: nextRoad ?? this.nextRoad,
      currentInstruction: currentInstruction ?? this.currentInstruction,
      nextInstruction: nextInstruction ?? this.nextInstruction,
      maneuver: maneuver ?? this.maneuver,
      distanceToNextManeuver: distanceToNextManeuver ?? this.distanceToNextManeuver,
      distanceRemaining: distanceRemaining ?? this.distanceRemaining,
      durationRemaining: durationRemaining ?? this.durationRemaining,
      eta: eta ?? this.eta,
      progress: progress ?? this.progress,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isRerouting: isRerouting ?? this.isRerouting,
      activeRoute: activeRoute ?? this.activeRoute,
    );
  }

  String get formattedDistanceRemaining {
    if (distanceRemaining >= 1000) {
      return '${(distanceRemaining / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceRemaining.round()} m';
  }

  String get formattedDistanceToNextManeuver {
    if (distanceToNextManeuver >= 1000) {
      return '${(distanceToNextManeuver / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceToNextManeuver.round()} m';
  }

  @override
  String toString() {
    return 'NavigationState(status: $status, instruction: "$currentInstruction", distToManeuver: ${distanceToNextManeuver.toStringAsFixed(0)}m, distRem: ${distanceRemaining.toStringAsFixed(0)}m, offRoute: $isOffRoute)';
  }
}
