import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/models/route.dart';
import '../core/models/vehicle.dart';
import '../core/errors/exceptions.dart';
import '../core/logging/logger.dart';

/// Abstract contract for route calculation providers (OSRM, OpenRouteService, Valhalla, GraphHopper).
abstract class RoutingProvider {
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    VehicleType vehicleType = VehicleType.car,
    bool alternatives = false,
  });
}

/// Free, open-source OSRM routing engine implementation.
class OSRMProvider implements RoutingProvider {
  final String baseUrl;
  final http.Client _httpClient;

  OSRMProvider({
    this.baseUrl = 'https://router.project-osrm.org',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    VehicleType vehicleType = VehicleType.car,
    bool alternatives = false,
  }) async {
    final profile = _mapVehicleTypeToProfile(vehicleType);
    final coordsList = [
      '${origin.longitude},${origin.latitude}',
      ...waypoints.map((w) => '${w.longitude},${w.latitude}'),
      '${destination.longitude},${destination.latitude}',
    ].join(';');

    final url = Uri.parse('$baseUrl/route/v1/$profile/$coordsList?overview=full&geometries=geojson&steps=true&alternatives=${alternatives ? "true" : "false"}');

    RouteEngineLogger.info('OSRMProvider', 'Fetching route: $url');

    try {
      final response = await _httpClient.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw FlutterRouteException(
          code: RouteErrorCode.routingFailed,
          message: 'OSRM routing server returned HTTP status ${response.statusCode}',
        );
      }

      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      final code = jsonMap['code'] as String?;
      if (code != 'Ok') {
        throw FlutterRouteException(
          code: RouteErrorCode.routeNotFound,
          message: 'No route found by OSRM provider: $code',
        );
      }

      final routes = jsonMap['routes'] as List<dynamic>;
      if (routes.isEmpty) {
        throw FlutterRouteException(
          code: RouteErrorCode.routeNotFound,
          message: 'No routes returned in response payload.',
        );
      }

      return _parseOSRMRoute(routes.first as Map<String, dynamic>, [origin, ...waypoints, destination]);
    } catch (e, stack) {
      if (e is FlutterRouteException) rethrow;
      throw FlutterRouteException(
        code: RouteErrorCode.routingFailed,
        message: 'Failed to communicate with OSRM routing server.',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  RouteResult _parseOSRMRoute(Map<String, dynamic> routeJson, List<LatLng> waypoints) {
    final distanceMeters = (routeJson['distance'] as num).toDouble();
    final durationSeconds = (routeJson['duration'] as num).toDouble();

    final geometryJson = routeJson['geometry'] as Map<String, dynamic>;
    final coordinates = geometryJson['coordinates'] as List<dynamic>;

    final List<LatLng> geometry = coordinates.map((c) {
      final list = c as List<dynamic>;
      return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
    }).toList();

    final legsJson = routeJson['legs'] as List<dynamic>;
    final List<RouteStep> steps = [];

    for (final leg in legsJson) {
      final legMap = leg as Map<String, dynamic>;
      final stepsJson = legMap['steps'] as List<dynamic>? ?? [];

      for (final s in stepsJson) {
        final stepMap = s as Map<String, dynamic>;
        final stepDistance = (stepMap['distance'] as num).toDouble();
        final stepDuration = (stepMap['duration'] as num).toDouble();

        final stepGeomJson = stepMap['geometry'] as Map<String, dynamic>;
        final stepCoords = (stepGeomJson['coordinates'] as List<dynamic>).map((c) {
          final list = c as List<dynamic>;
          return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
        }).toList();

        final maneuverJson = stepMap['maneuver'] as Map<String, dynamic>? ?? {};
        final maneuverTypeStr = maneuverJson['type'] as String? ?? '';
        final modifierStr = maneuverJson['modifier'] as String? ?? '';
        final instruction = stepMap['name'] != null && (stepMap['name'] as String).isNotEmpty
            ? 'In ${stepDistance.round()}m turn $modifierStr onto ${stepMap['name']}'
            : 'In ${stepDistance.round()}m $maneuverTypeStr $modifierStr';

        steps.add(RouteStep(
          instruction: instruction,
          maneuver: ManeuverType.fromString('$maneuverTypeStr $modifierStr'),
          distanceMeters: stepDistance,
          durationSeconds: stepDuration,
          startLocation: stepCoords.isNotEmpty ? stepCoords.first : geometry.first,
          endLocation: stepCoords.isNotEmpty ? stepCoords.last : geometry.last,
          geometry: stepCoords,
          roadName: stepMap['name'] as String?,
        ));
      }
    }

    return RouteResult(
      id: 'osrm_${DateTime.now().millisecondsSinceEpoch}',
      geometry: geometry,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      steps: steps,
      waypoints: waypoints,
    );
  }

  String _mapVehicleTypeToProfile(VehicleType type) {
    switch (type) {
      case VehicleType.bicycle:
        return 'bike';
      case VehicleType.pedestrian:
        return 'foot';
      case VehicleType.car:
      case VehicleType.truck:
      case VehicleType.motorcycle:
      case VehicleType.bus:
        return 'driving';
    }
  }
}

/// OpenRouteService Routing Provider.
class OpenRouteServiceProvider implements RoutingProvider {
  final String apiKey;
  final String baseUrl;
  final http.Client _httpClient;

  OpenRouteServiceProvider({
    required this.apiKey,
    this.baseUrl = 'https://api.openrouteservice.org/v2/directions',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    VehicleType vehicleType = VehicleType.car,
    bool alternatives = false,
  }) async {
    // Fallback to OSRM if no API key provided
    if (apiKey.isEmpty) {
      return OSRMProvider().calculateRoute(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        vehicleType: vehicleType,
        alternatives: alternatives,
      );
    }

    final profile = vehicleType == VehicleType.bicycle
        ? 'cycling-regular'
        : vehicleType == VehicleType.pedestrian
            ? 'foot-walking'
            : 'driving-car';

    final url = Uri.parse('$baseUrl/$profile/geojson');
    final body = json.encode({
      'coordinates': [
        [origin.longitude, origin.latitude],
        ...waypoints.map((w) => [w.longitude, w.latitude]),
        [destination.longitude, destination.latitude],
      ]
    });

    try {
      final response = await _httpClient.post(
        url,
        headers: {'Authorization': apiKey, 'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw FlutterRouteException(
          code: RouteErrorCode.routingFailed,
          message: 'OpenRouteService returned status ${response.statusCode}',
        );
      }

      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      final features = jsonMap['features'] as List<dynamic>;
      if (features.isEmpty) {
        throw FlutterRouteException(code: RouteErrorCode.routeNotFound, message: 'No route found by OpenRouteService');
      }

      final feature = features.first as Map<String, dynamic>;
      final geometryJson = feature['geometry'] as Map<String, dynamic>;
      final coords = geometryJson['coordinates'] as List<dynamic>;

      final geometry = coords.map((c) {
        final list = c as List<dynamic>;
        return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
      }).toList();

      final properties = feature['properties'] as Map<String, dynamic>;
      final summary = properties['summary'] as Map<String, dynamic>;

      return RouteResult(
        id: 'ors_${DateTime.now().millisecondsSinceEpoch}',
        geometry: geometry,
        distanceMeters: (summary['distance'] as num).toDouble(),
        durationSeconds: (summary['duration'] as num).toDouble(),
        steps: const [],
        waypoints: [origin, ...waypoints, destination],
      );
    } catch (e) {
      // Fallback to OSRM on error
      return OSRMProvider().calculateRoute(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        vehicleType: vehicleType,
      );
    }
  }
}

/// Central Routing Subsystem Manager.
class RoutingEngine {
  RoutingProvider provider;

  RoutingEngine({RoutingProvider? provider}) : provider = provider ?? OSRMProvider();

  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    VehicleType vehicleType = VehicleType.car,
    bool alternatives = false,
  }) {
    return provider.calculateRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      vehicleType: vehicleType,
      alternatives: alternatives,
    );
  }
}
