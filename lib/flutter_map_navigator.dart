library;

// Core Engine Facade
export 'src/flutter_route_engine.dart';

// Core Models
export 'src/core/models/geo_location.dart';
export 'src/core/models/permission_status.dart';
export 'src/core/models/background_tracking_state.dart';
export 'src/core/models/route.dart';
export 'src/core/models/navigation_state.dart';
export 'src/core/models/vehicle.dart';
export 'src/core/models/marker.dart';
export 'src/core/models/polyline.dart';
export 'src/core/models/search_result.dart';

// Errors & Utilities
export 'src/core/errors/exceptions.dart';
export 'src/core/logging/logger.dart';
export 'src/core/utils/geo_utils.dart';

// Subsystem Engine Managers
export 'src/engines/map_engine.dart';
export 'src/engines/location_engine.dart';
export 'src/engines/permission_manager.dart';
export 'src/engines/tracking_engine.dart';
export 'src/engines/background_tracking_engine.dart';
export 'src/engines/routing_engine.dart';
export 'src/engines/navigation_engine.dart';
export 'src/engines/off_route_detector.dart';
export 'src/engines/vehicle_engine.dart';
export 'src/engines/marker_engine.dart';
export 'src/engines/polyline_engine.dart';
export 'src/engines/search_engine.dart';
export 'src/engines/geocoding_engine.dart';
export 'src/engines/voice_engine.dart';
export 'src/engines/lifecycle_manager.dart';
export 'src/engines/battery_manager.dart';
export 'src/engines/network_manager.dart';
export 'src/engines/session_persistence.dart';
export 'src/engines/diagnostics_engine.dart';

// UI Widgets
export 'src/ui/map_navigator_view.dart';
export 'src/ui/navigation_hud_view.dart';
