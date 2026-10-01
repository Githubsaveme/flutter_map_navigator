import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

enum MarkerType { user, destination, waypoint, vehicle, custom }

/// Map marker definition.
class MapMarker {
  final String id;
  final LatLng position;
  final MarkerType type;
  final Widget? icon;
  final double width;
  final double height;
  final double rotation; // degrees
  final Alignment anchor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Map<String, dynamic> metadata;

  const MapMarker({
    required this.id,
    required this.position,
    this.type = MarkerType.custom,
    this.icon,
    this.width = 40.0,
    this.height = 40.0,
    this.rotation = 0.0,
    this.anchor = Alignment.center,
    this.onTap,
    this.onLongPress,
    this.metadata = const {},
  });

  MapMarker copyWith({
    String? id,
    LatLng? position,
    MarkerType? type,
    Widget? icon,
    double? width,
    double? height,
    double? rotation,
    Alignment? anchor,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Map<String, dynamic>? metadata,
  }) {
    return MapMarker(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      anchor: anchor ?? this.anchor,
      onTap: onTap ?? this.onTap,
      onLongPress: onLongPress ?? this.onLongPress,
      metadata: metadata ?? this.metadata,
    );
  }
}
