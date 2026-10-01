import 'dart:async';
import '../core/models/marker.dart';

/// Subsystem for interactive map markers and user icons.
class MarkerEngine {
  final Map<String, MapMarker> _markers = {};
  final StreamController<List<MapMarker>> _controller = StreamController<List<MapMarker>>.broadcast();

  Stream<List<MapMarker>> get markersStream => _controller.stream;
  List<MapMarker> get allMarkers => _markers.values.toList();

  void add(MapMarker marker) {
    _markers[marker.id] = marker;
    _notify();
  }

  void update(MapMarker marker) {
    _markers[marker.id] = marker;
    _notify();
  }

  void remove(String id) {
    _markers.remove(id);
    _notify();
  }

  MapMarker? get(String id) => _markers[id];

  void clear() {
    _markers.clear();
    _notify();
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(allMarkers);
    }
  }

  void dispose() {
    _controller.close();
  }
}
