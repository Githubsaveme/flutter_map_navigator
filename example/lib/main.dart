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
  Map<String, dynamic> _diagnosticReport = {};

  final TextEditingController _originController = TextEditingController(text: '30.9010, 75.8573');
  final TextEditingController _destinationController = TextEditingController(text: '30.7333, 76.7794');

  bool _showDebugPanel = false;
  bool _showTopNavBanner = true;
  bool _showPolylines = true;
  bool _isBottomCardExpanded = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    // 1. Request location permission & enable service
    _permStatus = await _engine.permissions.requestLocation();

    // 2. Listen to continuous location stream
    _engine.location.stream.listen((loc) {
      if (mounted) setState(() => _currentLocation = loc);
    });

    _engine.navigation.stateStream.listen((state) {
      if (mounted) setState(() => _navState = state);
    });

    // 3. Get immediate initial fix
    try {
      final initialLoc = await _engine.location.current();
      if (mounted) setState(() => _currentLocation = initialLoc);
    } catch (_) {}

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

  Future<void> _navigateToLocation(LatLng dest, String name) async {
    final startLatLng = _currentLocation?.toLatLng() ?? const LatLng(30.9010, 75.8573);

    // Add Destination Marker
    _engine.markers.add(MapMarker(
      id: 'destination_marker',
      position: dest,
      type: MarkerType.destination,
      icon: const Icon(Icons.location_on, color: Colors.redAccent, size: 48.0),
    ));

    // Calculate Route
    final route = await _engine.routing.calculateRoute(
      origin: startLatLng,
      destination: dest,
    );

    // Draw Polyline & Start Navigation
    _engine.polylines.add(MapPolyline(
      id: 'active_route',
      points: route.geometry,
      color: Colors.blueAccent,
      width: 6.0,
    ));

    await _engine.navigation.start(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Map Navigator'),
        actions: [
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Core Map View with Map Taps Disabled as requested
          MapNavigatorView(
            mapEngine: _engine.map,
            trackingEngine: _engine.tracking,
            markerEngine: _engine.markers,
            vehicleEngine: _engine.vehicles,
            polylineEngine: _engine.polylines,
            showControls: false, // Moved controls to bottom collapsible card
            onMapTap: null,       // Map tap disabled
          ),

          // 2. Top Turn-by-Turn Instruction Banner (Hideable via bottom control)
          if (_showTopNavBanner)
            NavigationHudView(
              state: _navState,
              isFreeCamera: _engine.tracking.cameraMode == CameraFollowMode.free,
              onSearchTap: () => _openSearchDelegate(context),
              onReCenter: () {
                setState(() => _engine.tracking.cameraMode = CameraFollowMode.navigation);
              },
              onToggleMute: () {
                _engine.voice.isEnabled ? _engine.voice.disable() : _engine.voice.enable();
                setState(() {});
              },
              onStopNavigation: () {
                _engine.navigation.stop();
                _engine.polylines.clear();
                _engine.markers.remove('destination_marker');
              },
            ),

          // 3. Collapsible Bottom Control Card (Contains Zoom In/Out, Polyline, Audio, Styles, Upper Banner Toggle)
          Positioned(
            left: 12.0,
            right: 12.0,
            bottom: _showDebugPanel ? 130.0 : 16.0,
            child: _buildBottomControlCard(),
          ),

          // 4. Debug Panel (Optional)
          if (_showDebugPanel) _buildDebugPanel(),
        ],
      ),

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
                  Text('Production Controls', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: Text('Permission: ${_permStatus.name}'),
              subtitle: const Text('Request location permissions'),
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
              leading: const Icon(Icons.alt_route),
              title: const Text('Manual Route Planner'),
              onTap: () {
                Navigator.pop(context);
                _showRoutePlannerDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Add Fleet Vehicles'),
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
              title: const Text('System Settings'),
              onTap: () => _engine.permissions.openSettings(),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Diagnostics Report'),
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

  Widget _buildBottomControlCard() {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapsed Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 24.0),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _navState.status != NavigationStatus.idle
                            ? (_navState.activeRoute != null
                                ? '${_navState.formattedDistanceRemaining} remaining'
                                : 'Navigating')
                            : '${_currentLocation?.speedKmh.toStringAsFixed(0) ?? "0"} km/h',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                      ),
                      Text(
                        _navState.status != NavigationStatus.idle
                            ? 'Maneuver: ${_navState.formattedDistanceToNextManeuver}'
                            : 'Tap arrow to open controls',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13.0),
                      ),
                    ],
                  ),
                ),

                // Audio Mute Toggle Button
                IconButton(
                  icon: Icon(
                    _engine.voice.isEnabled ? Icons.volume_up : Icons.volume_off,
                    color: _engine.voice.isEnabled ? Colors.blueAccent : Colors.grey,
                  ),
                  onPressed: () {
                    _engine.voice.isEnabled ? _engine.voice.disable() : _engine.voice.enable();
                    setState(() {});
                  },
                ),

                // Expand / Collapse Toggle Button
                IconButton(
                  icon: Icon(
                    _isBottomCardExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.black87,
                    size: 28.0,
                  ),
                  onPressed: () {
                    setState(() => _isBottomCardExpanded = !_isBottomCardExpanded);
                  },
                ),
              ],
            ),

            // Expanded Controls Grid Panel
            if (_isBottomCardExpanded) ...[
              const Divider(height: 20.0),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  // Re-Center Button
                  _buildControlIconButton(
                    icon: Icons.my_location,
                    label: 'Re-Center',
                    color: Colors.blueAccent,
                    onPressed: () {
                      _engine.tracking.cameraMode = CameraFollowMode.navigation;
                      setState(() {});
                    },
                  ),

                  // Map Style Switcher
                  _buildControlIconButton(
                    icon: Icons.layers,
                    label: 'Map Style',
                    color: Colors.purple,
                    onPressed: () {
                      if (_engine.map.currentStyle.preset == MapStylePreset.standard) {
                        _engine.map.setStyle(MapStyle.satellite);
                      } else if (_engine.map.currentStyle.preset == MapStylePreset.satellite) {
                        _engine.map.setStyle(MapStyle.dark);
                      } else {
                        _engine.map.setStyle(MapStyle.standard);
                      }
                      setState(() {});
                    },
                  ),

                  // Polyline Visibility Toggle
                  _buildControlIconButton(
                    icon: _showPolylines ? Icons.route : Icons.route_outlined,
                    label: _showPolylines ? 'Hide Route' : 'Show Route',
                    color: _showPolylines ? Colors.green : Colors.grey,
                    onPressed: () {
                      setState(() => _showPolylines = !_showPolylines);
                    },
                  ),

                  // Upper Navigation Banner Toggle
                  _buildControlIconButton(
                    icon: _showTopNavBanner ? Icons.visibility : Icons.visibility_off,
                    label: _showTopNavBanner ? 'Hide Top HUD' : 'Show Top HUD',
                    color: _showTopNavBanner ? Colors.indigo : Colors.grey,
                    onPressed: () {
                      setState(() => _showTopNavBanner = !_showTopNavBanner);
                    },
                  ),

                  // Audio Mute Toggle
                  _buildControlIconButton(
                    icon: _engine.voice.isEnabled ? Icons.volume_up : Icons.volume_off,
                    label: _engine.voice.isEnabled ? 'Mute Audio' : 'Unmute Audio',
                    color: _engine.voice.isEnabled ? Colors.orange : Colors.grey,
                    onPressed: () {
                      _engine.voice.isEnabled ? _engine.voice.disable() : _engine.voice.enable();
                      setState(() {});
                    },
                  ),

                  // Stop Navigation Button
                  if (_navState.status != NavigationStatus.idle)
                    _buildControlIconButton(
                      icon: Icons.close,
                      label: 'Stop Nav',
                      color: Colors.redAccent,
                      onPressed: () {
                        _engine.navigation.stop();
                        _engine.polylines.clear();
                        _engine.markers.remove('destination_marker');
                        setState(() {});
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22.0),
            ),
            const SizedBox(height: 4.0),
            Text(label, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _openSearchDelegate(BuildContext context) {
    showSearch(
      context: context,
      delegate: _LocationSearchDelegate(
        searchEngine: _engine.search,
        onSelected: (result) {
          _navigateToLocation(result.position, result.title);
        },
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Positioned(
      bottom: 20,
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
              final destParts = _destinationController.text.split(',');
              final destination = LatLng(double.parse(destParts[0].trim()), double.parse(destParts[1].trim()));

              _navigateToLocation(destination, 'Manual Route');
            },
            child: const Text('Start Navigation'),
          ),
        ],
      ),
    );
  }
}

class _LocationSearchDelegate extends SearchDelegate<SearchResult?> {
  final SearchEngine searchEngine;
  final void Function(SearchResult result) onSelected;

  _LocationSearchDelegate({
    required this.searchEngine,
    required this.onSelected,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Type a location to search'));
    }

    return FutureBuilder<List<SearchResult>>(
      future: searchEngine.query(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No locations found'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              leading: const Icon(Icons.location_on, color: Colors.redAccent),
              title: Text(item.title),
              subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                onSelected(item);
                close(context, item);
              },
            );
          },
        );
      },
    );
  }
}
