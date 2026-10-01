import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/models/polyline.dart';
import '../core/utils/geo_utils.dart';

/// Subsystem for route polylines and styling.
class PolylineEngine {
  final Map<String, MapPolyline> _polylines = {};
  final StreamController<List<MapPolyline>> _controller = StreamController<List<MapPolyline>>.broadcast();

  Stream<List<MapPolyline>> get polylinesStream => _controller.stream;
  List<MapPolyline> get allPolylines => _polylines.values.toList();

  void add(MapPolyline polyline) {
    _polylines[polyline.id] = polyline;
    _notify();
  }

  void update(MapPolyline polyline) {
    _polylines[polyline.id] = polyline;
    _notify();
  }

  void remove(String id) {
    _polylines.remove(id);
    _notify();
  }

  /// Dynamically updates active route polylines into completed (grey) and remaining (green/blue).
  void updateRouteProgress(List<LatLng> fullRouteGeometry, LatLng currentPosition) {
    if (fullRouteGeometry.isEmpty) return;

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < fullRouteGeometry.length; i++) {
      final d = GeoUtils.distanceMeters(currentPosition, fullRouteGeometry[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    final completedPoints = fullRouteGeometry.sublist(0, (closestIndex + 1).clamp(1, fullRouteGeometry.length));
    final remainingPoints = [currentPosition, ...fullRouteGeometry.sublist(closestIndex)];

    _polylines['route_completed'] = MapPolyline(
      id: 'route_completed',
      points: completedPoints,
      color: Colors.grey.withValues(alpha: 0.7),
      width: 6.0,
      zIndex: 1,
    );

    _polylines['route_remaining'] = MapPolyline(
      id: 'route_remaining',
      points: remainingPoints,
      color: Colors.blueAccent,
      width: 7.0,
      zIndex: 2,
    );

    _notify();
  }

  void clear() {
    _polylines.clear();
    _notify();
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(allPolylines);
    }
  }

  void dispose() {
    _controller.close();
  }
}
