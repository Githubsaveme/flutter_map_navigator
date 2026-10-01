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

/// Main Map View widget integrating tiles, animated location, markers, vehicles, and polylines.
class MapNavigatorView extends StatefulWidget {
  final MapEngine mapEngine;
  final TrackingEngine trackingEngine;
  final MarkerEngine markerEngine;
  final VehicleEngine vehicleEngine;
  final PolylineEngine polylineEngine;
  final void Function(LatLng position)? onMapTap;
  final void Function(LatLng position)? onMapLongPress;

  const MapNavigatorView({
    super.key,
    required this.mapEngine,
    required this.trackingEngine,
    required this.markerEngine,
    required this.vehicleEngine,
    required this.polylineEngine,
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapStyle>(
      valueListenable: widget.mapEngine.styleNotifier,
      builder: (context, style, _) {
        return FlutterMap(
          mapController: _flutterMapController,
          options: MapOptions(
            initialCenter: _currentLocation?.toLatLng() ?? const LatLng(20.5937, 78.9629),
            initialZoom: 15.0,
            onTap: (tapPosition, point) => widget.onMapTap?.call(point),
            onLongPress: (tapPosition, point) => widget.onMapLongPress?.call(point),
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                // User manually panned/rotated map -> switch to free mode
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
            PolylineLayer(
              polylines: _polylines.map((p) {
                return Polyline(
                  points: p.points,
                  color: p.color.withValues(alpha: p.opacity),
                  strokeWidth: p.width,
                  isDotted: p.pattern == sdk_polyline.PolylinePattern.dotted,
                );
              }).toList(),
            ),

            // 3. Markers & Vehicles & User Location Layer
            MarkerLayer(
              markers: [
                ..._buildCustomMarkers(),
                ..._buildVehicleMarkers(),
                if (_currentLocation != null) _buildUserLocationMarker(),
              ],
            ),
          ],
        );
      },
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
        child: Container(
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
            child: m.icon ?? const Icon(Icons.location_on, color: Colors.red, size: 36.0),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildVehicleMarkers() {
    return _vehicles.map((v) {
      return Marker(
        point: v.position,
        width: 44.0,
        height: 44.0,
        child: Transform.rotate(
          angle: v.heading * (pi / 180),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                _getVehicleIcon(v.type),
                color: Colors.white,
                size: 24.0,
              ),
            ),
          ),
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
