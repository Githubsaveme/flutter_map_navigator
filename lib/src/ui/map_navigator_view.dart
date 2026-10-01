import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../engines/map_engine.dart';
import '../engines/tracking_engine.dart';
import '../engines/marker_engine.dart';
import '../engines/vehicle_engine.dart';
import '../engines/polyline_engine.dart';
import '../core/models/geo_location.dart';
import '../core/models/marker.dart' as sdk_marker;
import '../core/models/polyline.dart' as sdk_polyline;
import '../core/models/vehicle.dart';

/// Main Map View widget integrating tiles, animated location, custom user/vehicle markers, and dynamic polylines.
class MapNavigatorView extends StatefulWidget {
  final MapEngine mapEngine;
  final TrackingEngine trackingEngine;
  final MarkerEngine markerEngine;
  final VehicleEngine vehicleEngine;
  final PolylineEngine polylineEngine;
  final Widget? userIconWidget; // Custom user vehicle icon/image
  final bool showControls;     // Floating zoom & center map controls
  final void Function(LatLng position)? onMapTap;
  final void Function(LatLng position)? onMapLongPress;

  const MapNavigatorView({
    super.key,
    required this.mapEngine,
    required this.trackingEngine,
    required this.markerEngine,
    required this.vehicleEngine,
    required this.polylineEngine,
    this.userIconWidget,
    this.showControls = true,
    this.onMapTap,
    this.onMapLongPress,
  });

  @override
  State<MapNavigatorView> createState() => _MapNavigatorViewState();
}

class _MapNavigatorViewState extends State<MapNavigatorView> {
  final MapController _flutterMapController = MapController();

  GeoLocation? _currentLocation;
  List<sdk_marker.MapMarker> _markers = [];
  List<Vehicle> _vehicles = [];
  List<sdk_polyline.MapPolyline> _polylines = [];
  bool _showPolylines = true;

  @override
  void initState() {
    super.initState();

    // Listen to animated location updates
    widget.trackingEngine.animatedLocationStream.listen((loc) {
      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
      });

      // Auto-follow user camera if follow mode active
      if (widget.trackingEngine.cameraMode != CameraFollowMode.free) {
        final rotation = widget.trackingEngine.cameraMode == CameraFollowMode.heading ||
                widget.trackingEngine.cameraMode == CameraFollowMode.navigation
            ? loc.heading
            : 0.0;

        _flutterMapController.moveAndRotate(loc.toLatLng(), _flutterMapController.camera.zoom, rotation);
      }
    });

    widget.markerEngine.markersStream.listen((m) {
      if (mounted) setState(() => _markers = m);
    });

    widget.vehicleEngine.vehiclesStream.listen((v) {
      if (mounted) setState(() => _vehicles = v);
    });

    widget.polylineEngine.polylinesStream.listen((p) {
      if (mounted) setState(() => _polylines = p);
    });
  }

  void zoomIn() {
    final currentZoom = _flutterMapController.camera.zoom;
    _flutterMapController.move(_flutterMapController.camera.center, (currentZoom + 1).clamp(1.0, 19.0));
  }

  void zoomOut() {
    final currentZoom = _flutterMapController.camera.zoom;
    _flutterMapController.move(_flutterMapController.camera.center, (currentZoom - 1).clamp(1.0, 19.0));
  }

  void centerOnUser() {
    if (_currentLocation != null) {
      widget.trackingEngine.cameraMode = CameraFollowMode.navigation;
      _flutterMapController.moveAndRotate(_currentLocation!.toLatLng(), 16.0, _currentLocation!.heading);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapStyle>(
      valueListenable: widget.mapEngine.styleNotifier,
      builder: (context, style, _) {
        return Stack(
          children: [
            FlutterMap(
              mapController: _flutterMapController,
              options: MapOptions(
                initialCenter: _currentLocation?.toLatLng() ?? const LatLng(20.5937, 78.9629),
                initialZoom: 16.0,
                maxZoom: 19.0,
                minZoom: 3.0,
                onTap: (tapPosition, point) => widget.onMapTap?.call(point),
                onLongPress: (tapPosition, point) => widget.onMapLongPress?.call(point),
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    widget.trackingEngine.cameraMode = CameraFollowMode.free;
                  }
                },
              ),
              children: [
                // 1. Map Tiles Layer
                TileLayer(
                  urlTemplate: style.tileUrlTemplate,
                  subdomains: style.subdomains,
                  userAgentPackageName: 'com.flutter_map_navigator',
                ),

                // 2. Polylines Layer
                if (_showPolylines)
                  PolylineLayer(
                    polylines: _polylines.map((p) {
                      return Polyline(
                        points: p.points,
                        color: p.color.withValues(alpha: p.opacity),
                        strokeWidth: p.width,
                        pattern: p.pattern == sdk_polyline.PolylinePattern.dotted
                            ? StrokePattern.dashed(segments: const [2, 4])
                            : (p.pattern == sdk_polyline.PolylinePattern.dashed
                                ? StrokePattern.dashed(segments: const [10, 5])
                                : const StrokePattern.solid()),
                      );
                    }).toList(),
                  ),

                // 3. Markers & Vehicles Layer
                MarkerLayer(
                  markers: [
                    ..._buildCustomMarkers(),
                    ..._buildVehicleMarkers(),
                    if (_currentLocation != null) _buildUserLocationMarker(),
                  ],
                ),
              ],
            ),

            // 4. Floating Map Side Control Bar
            if (widget.showControls)
              Positioned(
                right: 16.0,
                bottom: 120.0,
                child: Column(
                  children: [
                    _buildControlButton(icon: Icons.add, onPressed: zoomIn),
                    const SizedBox(height: 8.0),
                    _buildControlButton(icon: Icons.remove, onPressed: zoomOut),
                    const SizedBox(height: 8.0),
                    _buildControlButton(icon: Icons.my_location, onPressed: centerOnUser, color: Colors.blueAccent),
                    const SizedBox(height: 8.0),
                    _buildControlButton(
                      icon: Icons.layers,
                      onPressed: () {
                        if (widget.mapEngine.currentStyle.preset == MapStylePreset.standard) {
                          widget.mapEngine.setStyle(MapStyle.satellite);
                        } else if (widget.mapEngine.currentStyle.preset == MapStylePreset.satellite) {
                          widget.mapEngine.setStyle(MapStyle.dark);
                        } else {
                          widget.mapEngine.setStyle(MapStyle.standard);
                        }
                      },
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 8.0),
                    _buildControlButton(
                      icon: _showPolylines ? Icons.route : Icons.route_outlined,
                      onPressed: () {
                        setState(() => _showPolylines = !_showPolylines);
                      },
                      color: _showPolylines ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed, Color color = Colors.black87}) {
    return Material(
      elevation: 6.0,
      borderRadius: BorderRadius.circular(12.0),
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 48.0,
          height: 48.0,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.0)),
          child: Icon(icon, color: color, size: 24.0),
        ),
      ),
    );
  }

  Marker _buildUserLocationMarker() {
    final loc = _currentLocation!;
    return Marker(
      point: loc.toLatLng(),
      width: 50.0,
      height: 50.0,
      child: Transform.rotate(
        angle: loc.heading * (pi / 180),
        child: widget.userIconWidget ??
            Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.0),
              ),
              child: const Center(
                child: Icon(
                  Icons.navigation,
                  color: Colors.blueAccent,
                  size: 28.0,
                ),
              ),
            ),
      ),
    );
  }

  List<Marker> _buildCustomMarkers() {
    return _markers.map((m) {
      return Marker(
        point: m.position,
        width: m.width,
        height: m.height,
        alignment: m.anchor,
        child: GestureDetector(
          onTap: m.onTap,
          onLongPress: m.onLongPress,
          child: Transform.rotate(
            angle: m.rotation * (pi / 180),
            child: m.icon ?? const Icon(Icons.location_on, color: Colors.redAccent, size: 40.0),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildVehicleMarkers() {
    return _vehicles.map((v) {
      Widget vehicleWidget;

      if (v.customIconWidget != null) {
        vehicleWidget = v.customIconWidget!;
      } else if (v.iconAsset != null) {
        vehicleWidget = Image.asset(v.iconAsset!, filterQuality: FilterQuality.high);
      } else if (v.iconUrl != null) {
        vehicleWidget = Image.network(v.iconUrl!, filterQuality: FilterQuality.high);
      } else {
        vehicleWidget = Container(
          decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
          child: Center(
            child: Icon(_getVehicleIcon(v.type), color: Colors.white, size: 24.0),
          ),
        );
      }

      return Marker(
        point: v.position,
        width: 48.0,
        height: 48.0,
        child: Transform.rotate(
          angle: v.heading * (pi / 180),
          child: vehicleWidget,
        ),
      );
    }).toList();
  }

  IconData _getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.truck:
        return Icons.local_shipping;
      case VehicleType.motorcycle:
        return Icons.two_wheeler;
      case VehicleType.bicycle:
        return Icons.directions_bike;
      case VehicleType.pedestrian:
        return Icons.directions_walk;
      case VehicleType.bus:
        return Icons.directions_bus;
      case VehicleType.car:
        return Icons.directions_car;
    }
  }
}
