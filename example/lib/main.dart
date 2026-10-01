import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_navigator/flutter_map_navigator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: NavigationDemoApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class NavigationDemoApp extends StatefulWidget {
  const NavigationDemoApp({super.key});

  @override
  State<NavigationDemoApp> createState() => _NavigationDemoAppState();
}

class _NavigationDemoAppState extends State<NavigationDemoApp> {
  final FlutterRouteEngine _engine = FlutterRouteEngine();

  GeoLocation? _currentLocation;
  NavigationState _navState = NavigationState.initial();
  BackgroundTrackingState _bgState = const BackgroundTrackingState(
    isRunning: false,
    permissionGranted: false,
    serviceRunning: false,
  );

  LocationPermissionStatus _permStatus = LocationPermissionStatus.unknown;
  List<SearchResult> _searchResults = [];
  Map<String, dynamic> _diagnosticReport = {};

  final TextEditingController _originController = TextEditingController(text: '30.9010, 75.8573');
  final TextEditingController _destinationController = TextEditingController(text: '30.7333, 76.7794');
  final TextEditingController _searchController = TextEditingController();

  bool _showDebugPanel = true;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    _permStatus = await _engine.permissions.locationStatus();

    _engine.location.stream.listen((loc) {
      if (mounted) setState(() => _currentLocation = loc);
    });

    _engine.navigation.stateStream.listen((state) {
      if (mounted) setState(() => _navState = state);
    });

    _updateBgStatus();
    _refreshDiagnostics();
  }

  Future<void> _updateBgStatus() async {
    final status = await _engine.backgroundTracking.status();
    if (mounted) setState(() => _bgState = status);
  }

  Future<void> _refreshDiagnostics() async {
    final report = await _engine.diagnostics.report();
    if (mounted) setState(() => _diagnosticReport = report);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Map Navigator SDK'),
        actions: [
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Core Map View
          MapNavigatorView(
            mapEngine: _engine.map,
            trackingEngine: _engine.tracking,
            markerEngine: _engine.markers,
            vehicleEngine: _engine.vehicles,
            polylineEngine: _engine.polylines,
            onMapTap: (point) {
              _engine.markers.add(MapMarker(
                id: 'tap_marker_${point.latitude}',
                position: point,
                icon: const Icon(Icons.location_on, color: Colors.purple, size: 36),
              ));
            },
          ),

          // 2. Navigation HUD Overlay
          NavigationHudView(
            state: _navState,
            isFreeCamera: _engine.tracking.cameraMode == CameraFollowMode.free,
            onReCenter: () {
              setState(() => _engine.tracking.cameraMode = CameraFollowMode.navigation);
            },
            onToggleMute: () {
              _engine.voice.isEnabled ? _engine.voice.disable() : _engine.voice.enable();
            },
            onStopNavigation: () {
              _engine.navigation.stop();
              _engine.polylines.clear();
            },
          ),

          // 3. Floating Debug Diagnostics Panel
          if (_showDebugPanel) _buildDebugPanel(),
        ],
      ),

      // Control Drawer
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.map, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text('Navigation SDK', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Production SDK Controls', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: Text('Permission: ${_permStatus.name}'),
              subtitle: const Text('Tap to request location permission'),
              onTap: () async {
                final status = await _engine.permissions.requestLocation();
                setState(() => _permStatus = status);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sensors),
              title: Text('Background Service: ${_bgState.isRunning ? "RUNNING" : "STOPPED"}'),
              subtitle: const Text('Toggle Foreground Service'),
              onTap: () async {
                if (_bgState.isRunning) {
                  await _engine.backgroundTracking.stop();
                } else {
                  await _engine.backgroundTracking.start();
                }
                _updateBgStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('Map Style'),
              trailing: PopupMenuButton<MapStylePreset>(
                onSelected: (preset) {
                  if (preset == MapStylePreset.satellite) _engine.map.setStyle(MapStyle.satellite);
                  if (preset == MapStylePreset.dark) _engine.map.setStyle(MapStyle.dark);
                  if (preset == MapStylePreset.standard) _engine.map.setStyle(MapStyle.standard);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: MapStylePreset.standard, child: Text('Standard (OSM)')),
                  PopupMenuItem(value: MapStylePreset.satellite, child: Text('Satellite')),
                  PopupMenuItem(value: MapStylePreset.dark, child: Text('Dark Mode')),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.alt_route),
              title: const Text('Route & Navigation Planner'),
              onTap: () => _showRoutePlannerDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search & Geocoding'),
              onTap: () => _showSearchDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Simulate Vehicle Fleet'),
              onTap: () {
                _engine.vehicles.add(Vehicle(
                  id: 'truck_101',
                  name: 'Fleet Truck 101',
                  type: VehicleType.truck,
                  position: const LatLng(30.9100, 75.8600),
                  heading: 45.0,
                  speed: 15.0,
                  lastUpdated: DateTime.now(),
                ));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Test Voice Prompt'),
              onTap: () {
                _engine.voice.speak('In 300 meters, turn right onto Main Street.');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Open System Settings'),
              onTap: () => _engine.permissions.openSettings(),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Run Diagnostics'),
              onTap: () async {
                await _refreshDiagnostics();
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Diagnostic Report'),
                      content: SingleChildScrollView(child: Text(_diagnosticReport.toString())),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Positioned(
      bottom: 90,
      left: 12,
      right: 12,
      child: Card(
        color: Colors.black.withValues(alpha: 0.85),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('LIVE DIAGNOSTICS DEBUG PANEL', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                'GPS Fix: ${_currentLocation?.latitude.toStringAsFixed(4)}, ${_currentLocation?.longitude.toStringAsFixed(4)} | Acc: ${_currentLocation?.accuracy.toStringAsFixed(1)}m | Speed: ${_currentLocation?.speedKmh.toStringAsFixed(1)}km/h | Heading: ${_currentLocation?.heading.toStringAsFixed(0)}°',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Text(
                'Permission: ${_permStatus.name} | Bg Service: ${_bgState.isRunning ? "ACTIVE" : "INACTIVE"} | Nav Status: ${_navState.status.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              if (_navState.status != NavigationStatus.idle)
                Text(
                  'Dist Rem: ${_navState.formattedDistanceRemaining} | Maneuver: ${_navState.formattedDistanceToNextManeuver} | OffRoute: ${_navState.isOffRoute}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoutePlannerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plan Route & Navigation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _originController, decoration: const InputDecoration(labelText: 'Origin (lat, lng)')),
            TextField(controller: _destinationController, decoration: const InputDecoration(labelText: 'Destination (lat, lng)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final origParts = _originController.text.split(',');
              final destParts = _destinationController.text.split(',');

              final origin = LatLng(double.parse(origParts[0].trim()), double.parse(origParts[1].trim()));
              final destination = LatLng(double.parse(destParts[0].trim()), double.parse(destParts[1].trim()));

              final route = await _engine.routing.calculateRoute(origin: origin, destination: destination);

              _engine.polylines.add(MapPolyline(id: 'planned_route', points: route.geometry, color: Colors.blue, width: 6));
              await _engine.navigation.start(route);
            },
            child: const Text('Start Navigation'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Locations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Search query (e.g. Ludhiana)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final results = await _engine.search.query(_searchController.text);
                setState(() => _searchResults = results);
              },
              child: const Text('Search'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              width: 300,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.subtitle, maxLines: 1),
                    onTap: () {
                      _engine.markers.add(MapMarker(
                        id: 'search_res_$index',
                        position: item.position,
                        icon: const Icon(Icons.pin_drop, color: Colors.redAccent, size: 36),
                      ));
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
