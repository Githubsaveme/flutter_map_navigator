import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../core/models/vehicle.dart';

/// Subsystem for multi-vehicle live tracking, status updates, and map markers.
class VehicleEngine {
  final Map<String, Vehicle> _vehicles = {};
  final StreamController<List<Vehicle>> _controller = StreamController<List<Vehicle>>.broadcast();

  Stream<List<Vehicle>> get vehiclesStream => _controller.stream;
  List<Vehicle> get allVehicles => _vehicles.values.toList();

  void add(Vehicle vehicle) {
    _vehicles[vehicle.id] = vehicle;
    _notify();
  }

  void update(
    String id, {
    LatLng? position,
    double? heading,
    double? speed,
    bool? isOnline,
    Map<String, dynamic>? metadata,
  }) {
    final existing = _vehicles[id];
    if (existing == null) return;

    _vehicles[id] = existing.copyWith(
      position: position ?? existing.position,
      heading: heading ?? existing.heading,
      speed: speed ?? existing.speed,
      isOnline: isOnline ?? existing.isOnline,
      metadata: metadata ?? existing.metadata,
      lastUpdated: DateTime.now(),
    );
    _notify();
  }

  void remove(String id) {
    _vehicles.remove(id);
    _notify();
  }

  Vehicle? get(String id) => _vehicles[id];

  void clear() {
    _vehicles.clear();
    _notify();
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(allVehicles);
    }
  }

  void dispose() {
    _controller.close();
  }
}
