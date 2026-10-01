import 'package:flutter/services.dart';
import 'permission_manager.dart';
import 'background_tracking_engine.dart';
import 'network_manager.dart';

/// Subsystem that produces complete diagnostic reports for production troubleshooting.
class DiagnosticsEngine {
  static const MethodChannel _channel = MethodChannel('com.flutter_map_navigator/methods');

  final PermissionManager permissions;
  final BackgroundTrackingEngine backgroundTracking;
  final NetworkManager network;

  DiagnosticsEngine({
    required this.permissions,
    required this.backgroundTracking,
    required this.network,
  });

  Future<Map<String, dynamic>> report() async {
    final Map<String, dynamic> reportMap = {};

    try {
      final nativeDiag = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
      if (nativeDiag != null) {
        reportMap.addAll(Map<String, dynamic>.from(nativeDiag));
      }
    } catch (_) {
      reportMap['nativeDiagnosticsError'] = 'Failed to fetch native diagnostics';
    }

    reportMap['locationPermissionStatus'] = (await permissions.locationStatus()).name;
    reportMap['backgroundTrackingStatus'] = (await backgroundTracking.status()).toString();
    reportMap['networkConnected'] = await network.isConnected();
    reportMap['timestamp'] = DateTime.now().toIso8601String();

    return reportMap;
  }
}
