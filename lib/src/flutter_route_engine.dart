import 'engines/map_engine.dart';
import 'engines/location_engine.dart';
import 'engines/permission_manager.dart';
import 'engines/tracking_engine.dart';
import 'engines/background_tracking_engine.dart';
import 'engines/routing_engine.dart';
import 'engines/navigation_engine.dart';
import 'engines/vehicle_engine.dart';
import 'engines/marker_engine.dart';
import 'engines/polyline_engine.dart';
import 'engines/search_engine.dart';
import 'engines/geocoding_engine.dart';
import 'engines/voice_engine.dart';
import 'engines/lifecycle_manager.dart';
import 'engines/battery_manager.dart';
import 'engines/network_manager.dart';
import 'engines/session_persistence.dart';
import 'engines/diagnostics_engine.dart';
import 'core/logging/logger.dart';

/// Production-grade Flutter Navigation & Tracking Engine SDK.
class FlutterRouteEngine {
  final MapEngine map;
  final LocationEngine location;
  final PermissionManager permissions;
  final TrackingEngine tracking;
  final BackgroundTrackingEngine backgroundTracking;
  final RoutingEngine routing;
  final NavigationEngine navigation;
  final VehicleEngine vehicles;
  final MarkerEngine markers;
  final PolylineEngine polylines;
  final SearchEngine search;
  final GeocodingEngine geocoding;
  final VoiceEngine voice;
  final LifecycleManager lifecycle;
  final BatteryManager battery;
  final NetworkManager network;
  final SessionPersistence persistence;
  final DiagnosticsEngine diagnostics;

  FlutterRouteEngine._({
    required this.map,
    required this.location,
    required this.permissions,
    required this.tracking,
    required this.backgroundTracking,
    required this.routing,
    required this.navigation,
    required this.vehicles,
    required this.markers,
    required this.polylines,
    required this.search,
    required this.geocoding,
    required this.voice,
    required this.lifecycle,
    required this.battery,
    required this.network,
    required this.persistence,
    required this.diagnostics,
  });

  factory FlutterRouteEngine() {
    final map = MapEngine();
    final location = LocationEngine();
    final permissions = PermissionManager();
    final tracking = TrackingEngine();
    final backgroundTracking = BackgroundTrackingEngine();
    final routing = RoutingEngine();
    final voice = VoiceEngine();
    final navigation = NavigationEngine(routingEngine: routing, voiceEngine: voice);
    final vehicles = VehicleEngine();
    final markers = MarkerEngine();
    final polylines = PolylineEngine();
    final search = SearchEngine();
    final geocoding = GeocodingEngine();
    final lifecycle = LifecycleManager();
    final battery = BatteryManager();
    final network = NetworkManager();
    final persistence = SessionPersistence();
    final diagnostics = DiagnosticsEngine(
      permissions: permissions,
      backgroundTracking: backgroundTracking,
      network: network,
    );

    final engine = FlutterRouteEngine._(
      map: map,
      location: location,
      permissions: permissions,
      tracking: tracking,
      backgroundTracking: backgroundTracking,
      routing: routing,
      navigation: navigation,
      vehicles: vehicles,
      markers: markers,
      polylines: polylines,
      search: search,
      geocoding: geocoding,
      voice: voice,
      lifecycle: lifecycle,
      battery: battery,
      network: network,
      persistence: persistence,
      diagnostics: diagnostics,
    );

    engine._initialize();
    return engine;
  }

  void _initialize() {
    RouteEngineLogger.info('FlutterRouteEngine', 'Initializing Navigation SDK');

    // Pipe location stream to tracking animator and navigation turn-by-turn state machine
    location.stream.listen((loc) {
      tracking.updateTargetLocation(loc);
      navigation.updateLocation(loc);

      // Update dynamic polyline progress if navigation active
      if (navigation.activeRoute != null) {
        polylines.updateRouteProgress(navigation.activeRoute!.geometry, loc.toLatLng());
      }
    });
  }

  /// Cleans up native resources, streams, tickers, and listeners.
  Future<void> dispose() async {
    RouteEngineLogger.info('FlutterRouteEngine', 'Disposing Navigation SDK');
    location.dispose();
    tracking.dispose();
    navigation.dispose();
    vehicles.dispose();
    markers.dispose();
    polylines.dispose();
    lifecycle.dispose();
  }
}
