# Flutter Map Navigator (`flutter_map_navigator`)

A production-grade, open-source Flutter navigation plugin and SDK built from scratch for real-time turn-by-turn navigation, foreground/background location tracking, vehicle tracking, automatic rerouting, and voice navigation.

---

## Architecture Overview

`flutter_map_navigator` follows a clean, modular architecture composed of independent subsystem engines and provider abstractions:

```text
FlutterRouteEngine
├── MapEngine                 (Tile styling: Standard OSM, Satellite, Dark, Custom Tile Server)
├── LocationEngine            (GPS stream, accuracy validation, Kalman noise filtering)
├── PermissionManager         (Fine, Coarse, Background location permissions, System Settings)
├── TrackingEngine            (60fps smooth position/heading interpolation & camera follow modes)
├── BackgroundTrackingEngine  (Android Foreground Service & iOS CoreLocation background updates)
├── RoutingEngine             (OSRM, OpenRouteService, Valhalla, GraphHopper abstraction)
├── NavigationEngine          (Turn-by-turn state machine, route step progress)
├── OffRouteDetector          (Cross-track distance calculation, consecutive off-route verification)
├── VehicleEngine             (Multi-vehicle fleet registry, live position/heading updates)
├── MarkerEngine              (Interactive markers, user icons, tap/long-press events)
├── PolylineEngine            (Dynamic route polyline splitting: completed vs remaining route)
├── SearchEngine              (POI query, address suggestions)
├── GeocodingEngine           (Forward & reverse geocoding)
├── VoiceEngine               (TTS maneuver announcements, cooldown & deduplication)
├── LifecycleManager          (App foreground/background state transition handler)
├── BatteryManager            (LowPower, Balanced, Navigation, HighAccuracy tracking modes)
├── NetworkManager            (Network availability checking and retry logic)
├── SessionPersistence        (Active navigation state save & restore across app restarts)
└── DiagnosticsEngine         (System diagnostic report generator for troubleshooting)
```

---

## Key Features

- **Production-Grade Location Tracking**: Fused Location Provider (Android) and CoreLocation (iOS) integration with Kalman filtering for GPS drift and jump elimination.
- **Android Foreground Service**: Persistent notification support to ensure background tracking survives activity destruction and backgrounding.
- **iOS Background Location**: CoreLocation `allowsBackgroundLocationUpdates` configuration for background navigation.
- **Turn-by-Turn Navigation State Machine**: States include `idle`, `calculating`, `ready`, `starting`, `navigating`, `rerouting`, `arrived`, `paused`, `stopped`, `error`.
- **Automatic Rerouting**: Off-route detection calculates orthogonal distance to route segments, applies location accuracy weighting, confirms consecutive off-route fixes, and triggers rerouting without endless loops.
- **Voice Navigation (TTS)**: Contextual maneuver speech prompts with automatic cooldown to prevent audio repetition.
- **Smooth 60fps Vehicle & Marker Animation**: Linear interpolation (lerp) for coordinates and 360° heading wrap-around smoothing.
- **Multi-Vehicle Fleet Tracking**: Support for cars, trucks, motorcycles, bicycles, buses, and pedestrians with live heading/speed updates.
- **Provider Abstraction**: Decoupled Map Provider, Routing Provider (OSRM / OpenRouteService), Geocoding Provider, and Voice Provider.

---

## Setup & Configuration

### Android Setup

In `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<application>
    <service
        android:name="com.flutter_map_navigator.TrackingForegroundService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="location" />
</application>
```

### iOS Setup

In `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app requires location access for turn-by-turn navigation.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app requires background location access for continuous navigation tracking.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

---

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_navigator/flutter_map_navigator.dart';

void main() {
  runApp(const MaterialApp(home: NavigationScreen()));
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final FlutterRouteEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = FlutterRouteEngine();
    _startNavigation();
  }

  Future<void> _startNavigation() async {
    // 1. Check & Request Permissions
    final perm = await _engine.permissions.requestLocation();
    if (!perm.isGranted) return;

    // 2. Calculate Route
    final route = await _engine.routing.calculateRoute(
      origin: const LatLng(30.9010, 75.8573), // Ludhiana
      destination: const LatLng(30.7333, 76.7794), // Chandigarh
    );

    // 3. Start Background Service
    await _engine.backgroundTracking.start(
      notificationTitle: 'Navigating to Chandigarh',
      notificationText: 'Turn-by-turn tracking active',
    );

    // 4. Start Turn-by-Turn Engine
    await _engine.navigation.start(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapNavigatorView(
            mapEngine: _engine.map,
            trackingEngine: _engine.tracking,
            markerEngine: _engine.markers,
            vehicleEngine: _engine.vehicles,
            polylineEngine: _engine.polylines,
          ),
          StreamBuilder<NavigationState>(
            stream: _engine.navigation.stateStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return NavigationHudView(
                state: snapshot.data!,
                onStopNavigation: () {
                  _engine.navigation.stop();
                  _engine.backgroundTracking.stop();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
```

---

## License

MIT License.
