import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum MapStylePreset { standard, satellite, dark, custom }

class MapStyle {
  final MapStylePreset preset;
  final String tileUrlTemplate;
  final List<String> subdomains;

  const MapStyle({
    required this.preset,
    required this.tileUrlTemplate,
    this.subdomains = const ['a', 'b', 'c'],
  });

  static const MapStyle standard = MapStyle(
    preset: MapStylePreset.standard,
    tileUrlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const MapStyle satellite = MapStyle(
    preset: MapStylePreset.satellite,
    tileUrlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    subdomains: [],
  );

  static const MapStyle dark = MapStyle(
    preset: MapStylePreset.dark,
    tileUrlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
  );

  factory MapStyle.custom(String urlTemplate, {List<String> subdomains = const ['a', 'b', 'c']}) {
    return MapStyle(
      preset: MapStylePreset.custom,
      tileUrlTemplate: urlTemplate,
      subdomains: subdomains,
    );
  }
}

/// Subsystem for map tile styles and camera state.
class MapEngine {
  MapStyle _currentStyle = MapStyle.standard;
  double _zoom = 15.0;
  double _rotation = 0.0;
  LatLng _center = const LatLng(0.0, 0.0);

  final ValueNotifier<MapStyle> styleNotifier = ValueNotifier<MapStyle>(MapStyle.standard);

  MapStyle get currentStyle => _currentStyle;
  double get zoom => _zoom;
  double get rotation => _rotation;
  LatLng get center => _center;

  void setStyle(MapStyle style) {
    _currentStyle = style;
    styleNotifier.value = style;
  }

  void updateCamera({LatLng? center, double? zoom, double? rotation}) {
    if (center != null) _center = center;
    if (zoom != null) _zoom = zoom;
    if (rotation != null) _rotation = rotation;
  }
}
