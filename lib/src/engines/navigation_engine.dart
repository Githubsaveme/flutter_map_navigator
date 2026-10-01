import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../core/models/geo_location.dart';
import '../core/models/navigation_state.dart';
import '../core/models/route.dart';
import '../core/utils/geo_utils.dart';
import '../core/logging/logger.dart';
import 'off_route_detector.dart';
import 'routing_engine.dart';
import 'voice_engine.dart';

/// Turn-by-Turn Navigation Engine and State Machine.
class NavigationEngine {
  final RoutingEngine routingEngine;
  final VoiceEngine voiceEngine;
  final OffRouteDetector offRouteDetector;

  final StreamController<NavigationState> _stateController = StreamController<NavigationState>.broadcast();
  NavigationState _currentState = NavigationState.initial();

  RouteResult? _activeRoute;
  int _currentStepIndex = 0;

  NavigationEngine({
    required this.routingEngine,
    required this.voiceEngine,
    OffRouteDetector? offRouteDetector,
  }) : offRouteDetector = offRouteDetector ?? OffRouteDetector();

  Stream<NavigationState> get stateStream => _stateController.stream;
  NavigationState get state => _currentState;
  RouteResult? get activeRoute => _activeRoute;

  /// Starts turn-by-turn navigation on a calculated route.
  Future<void> start(RouteResult route) async {
    _activeRoute = route;
    _currentStepIndex = 0;
    offRouteDetector.reset();

    _currentState = NavigationState(
      status: NavigationStatus.starting,
      activeRoute: route,
      distanceRemaining: route.distanceMeters,
      durationRemaining: route.durationSeconds,
      eta: DateTime.now().add(Duration(seconds: route.durationSeconds.round())),
      currentInstruction: route.steps.isNotEmpty ? route.steps.first.instruction : 'Start route',
      maneuver: route.steps.isNotEmpty ? route.steps.first.maneuver : ManeuverType.depart,
    );

    _emitState(_currentState);

    await voiceEngine.speak('Navigation starting. ${_currentState.currentInstruction}');
    _currentState = _currentState.copyWith(status: NavigationStatus.navigating);
    _emitState(_currentState);
  }

  /// Processes a location fix and updates turn-by-turn progress.
  Future<void> updateLocation(GeoLocation location) async {
    if (_currentState.status != NavigationStatus.navigating &&
        _currentState.status != NavigationStatus.starting) {
      return;
    }

    final route = _activeRoute;
    if (route == null || route.geometry.isEmpty) return;

    // 1. Check for arrival at destination
    final destination = route.geometry.last;
    final distToDest = GeoUtils.distanceMeters(location.toLatLng(), destination);

    if (distToDest <= 25.0) {
      _currentState = _currentState.copyWith(
        status: NavigationStatus.arrived,
        currentLocation: location,
        distanceRemaining: 0.0,
        durationRemaining: 0.0,
        progress: 1.0,
        currentInstruction: 'You have arrived at your destination.',
        maneuver: ManeuverType.arrive,
      );
      _emitState(_currentState);
      await voiceEngine.speak('You have arrived at your destination.');
      return;
    }

    // 2. Off-route detection & automatic rerouting
    if (offRouteDetector.evaluatePosition(location, route)) {
      await _performAutomaticReroute(location, destination);
      return;
    }

    // 3. Progress along active steps
    _updateProgressAndStep(location, route);
  }

  void _updateProgressAndStep(GeoLocation location, RouteResult route) {
    if (route.steps.isEmpty) return;

    final currentStep = route.steps[_currentStepIndex.clamp(0, route.steps.length - 1)];
    final distToStepEnd = GeoUtils.distanceMeters(location.toLatLng(), currentStep.endLocation);

    // Advance to next step when within 25 meters of step transition
    if (distToStepEnd < 25.0 && _currentStepIndex < route.steps.length - 1) {
      _currentStepIndex++;
      final nextStep = route.steps[_currentStepIndex];
      voiceEngine.announceManeuver(nextStep.instruction, distToStepEnd);
    }

    final nextManeuverStep = route.steps[_currentStepIndex.clamp(0, route.steps.length - 1)];
    final distToManeuver = GeoUtils.distanceMeters(location.toLatLng(), nextManeuverStep.endLocation);

    // Calculate total remaining distance along remaining route geometry
    final remainingDist = _calculateRemainingDistance(location.toLatLng(), route.geometry);
    final progress = (1.0 - (remainingDist / (route.distanceMeters > 0 ? route.distanceMeters : 1.0))).clamp(0.0, 1.0);
    final remainingDuration = (1.0 - progress) * route.durationSeconds;

    _currentState = _currentState.copyWith(
      currentLocation: location,
      currentInstruction: nextManeuverStep.instruction,
      nextInstruction: _currentStepIndex < route.steps.length - 1 ? route.steps[_currentStepIndex + 1].instruction : '',
      maneuver: nextManeuverStep.maneuver,
      distanceToNextManeuver: distToManeuver,
      distanceRemaining: remainingDist,
      durationRemaining: remainingDuration,
      eta: DateTime.now().add(Duration(seconds: remainingDuration.round())),
      progress: progress,
      isOffRoute: false,
      isRerouting: false,
      currentRoad: nextManeuverStep.roadName ?? '',
    );

    _emitState(_currentState);
    voiceEngine.announceManeuver(nextManeuverStep.instruction, distToManeuver);
  }

  Future<void> _performAutomaticReroute(GeoLocation location, LatLng destination) async {
    RouteEngineLogger.warning('NavigationEngine', 'Performing automatic reroute...');
    _currentState = _currentState.copyWith(
      status: NavigationStatus.rerouting,
      isOffRoute: true,
      isRerouting: true,
      currentInstruction: 'Rerouting...',
    );
    _emitState(_currentState);

    try {
      final newRoute = await routingEngine.calculateRoute(
        origin: location.toLatLng(),
        destination: destination,
      );

      _activeRoute = newRoute;
      _currentStepIndex = 0;
      offRouteDetector.reset();

      _currentState = _currentState.copyWith(
        status: NavigationStatus.navigating,
        activeRoute: newRoute,
        isOffRoute: false,
        isRerouting: false,
        currentInstruction: newRoute.steps.isNotEmpty ? newRoute.steps.first.instruction : 'New route calculated',
      );

      _emitState(_currentState);
      await voiceEngine.speak('New route calculated.');
    } catch (e, stack) {
      RouteEngineLogger.error('NavigationEngine', 'Rerouting failed', e, stack);
      _currentState = _currentState.copyWith(
        status: NavigationStatus.error,
        isRerouting: false,
        currentInstruction: 'Rerouting failed. Retrying shortly...',
      );
      _emitState(_currentState);
    }
  }

  double _calculateRemainingDistance(LatLng currentPos, List<LatLng> geometry) {
    if (geometry.isEmpty) return 0.0;
    int closestIdx = 0;
    double minDist = double.infinity;

    for (int i = 0; i < geometry.length; i++) {
      final d = GeoUtils.distanceMeters(currentPos, geometry[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    double totalRemaining = minDist;
    for (int i = closestIdx; i < geometry.length - 1; i++) {
      totalRemaining += GeoUtils.distanceMeters(geometry[i], geometry[i + 1]);
    }
    return totalRemaining;
  }

  void pause() {
    _currentState = _currentState.copyWith(status: NavigationStatus.paused);
    _emitState(_currentState);
  }

  void resume() {
    _currentState = _currentState.copyWith(status: NavigationStatus.navigating);
    _emitState(_currentState);
  }

  void stop() {
    _currentState = NavigationState.initial();
    _activeRoute = null;
    _currentStepIndex = 0;
    offRouteDetector.reset();
    _emitState(_currentState);
  }

  void _emitState(NavigationState s) {
    _currentState = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  void dispose() {
    _stateController.close();
  }
}
