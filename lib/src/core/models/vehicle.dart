import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

enum VehicleType { car, truck, motorcycle, bicycle, pedestrian, bus }

/// Represents a live tracked vehicle or user icon on the map.
class Vehicle {
  final String id;
  final String name;
  final VehicleType type;
  final LatLng position;
  final double heading; // degrees (0..360)
  final double speed; // m/s
  final bool isOnline;
  final String? iconAsset; // e.g. 'assets/car.png'
  final String? iconUrl;   // Remote image URL from server
  final Widget? customIconWidget; // Custom Flutter Widget
  final Map<String, dynamic> metadata;
  final DateTime lastUpdated;

  const Vehicle({
    required this.id,
    required this.name,
    this.type = VehicleType.car,
    required this.position,
    this.heading = 0.0,
    this.speed = 0.0,
    this.isOnline = true,
    this.iconAsset,
    this.iconUrl,
    this.customIconWidget,
    this.metadata = const {},
    required this.lastUpdated,
  });

  Vehicle copyWith({
    String? id,
    String? name,
    VehicleType? type,
    LatLng? position,
    double? heading,
    double? speed,
    bool? isOnline,
    String? iconAsset,
    String? iconUrl,
    Widget? customIconWidget,
    Map<String, dynamic>? metadata,
    DateTime? lastUpdated,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      position: position ?? this.position,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isOnline: isOnline ?? this.isOnline,
      iconAsset: iconAsset ?? this.iconAsset,
      iconUrl: iconUrl ?? this.iconUrl,
      customIconWidget: customIconWidget ?? this.customIconWidget,
      metadata: metadata ?? this.metadata,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
