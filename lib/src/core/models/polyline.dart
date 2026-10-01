import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum PolylinePattern { solid, dotted, dashed }

/// Represents map route or boundary polylines.
class MapPolyline {
  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
  final double opacity;
  final PolylinePattern pattern;
  final bool isVisible;
  final int zIndex;

  const MapPolyline({
    required this.id,
    required this.points,
    this.color = Colors.blue,
    this.width = 5.0,
    this.opacity = 1.0,
    this.pattern = PolylinePattern.solid,
    this.isVisible = true,
    this.zIndex = 1,
  });

  MapPolyline copyWith({
    String? id,
    List<LatLng>? points,
    Color? color,
    double? width,
    double? opacity,
    PolylinePattern? pattern,
    bool? isVisible,
    int? zIndex,
  }) {
    return MapPolyline(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      pattern: pattern ?? this.pattern,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}
