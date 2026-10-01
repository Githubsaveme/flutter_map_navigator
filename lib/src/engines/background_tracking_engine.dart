import 'dart:async';
import 'package:flutter/services.dart';
import '../core/models/background_tracking_state.dart';
import '../core/logging/logger.dart';

/// Subsystem for controlling Android Foreground Services & iOS Background Location.
class BackgroundTrackingEngine {
  static const MethodChannel _channel = MethodChannel('com.flutter_map_navigator/methods');

  /// Starts background location tracking and launches persistent foreground service on Android.
  Future<bool> start({
    String notificationTitle = 'Navigation Active',
    String notificationText = 'Tracking location in background',
  }) async {
    try {
      RouteEngineLogger.info('BackgroundTrackingEngine', 'Starting background tracking');
      final bool? success = await _channel.invokeMethod<bool>('startBackgroundTracking', {
        'notificationTitle': notificationTitle,
        'notificationText': notificationText,
      });
      return success ?? false;
    } catch (e, stack) {
      RouteEngineLogger.error('BackgroundTrackingEngine', 'Failed to start background tracking', e, stack);
      return false;
    }
  }

  /// Updates the foreground notification text while navigating.
  Future<void> updateNotification({required String title, required String text}) async {
    try {
      await _channel.invokeMethod('updateNotification', {
        'notificationTitle': title,
        'notificationText': text,
      });
    } catch (e) {
      // Ignored if service not active
    }
  }

  /// Stops background tracking foreground service.
  Future<bool> stop() async {
    try {
      RouteEngineLogger.info('BackgroundTrackingEngine', 'Stopping background tracking');
      final bool? success = await _channel.invokeMethod<bool>('stopBackgroundTracking');
      return success ?? false;
    } catch (e, stack) {
      RouteEngineLogger.error('BackgroundTrackingEngine', 'Failed to stop background tracking', e, stack);
      return false;
    }
  }

  /// Returns current background service status.
  Future<BackgroundTrackingState> status() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBackgroundTrackingStatus');
      if (res != null) {
        return BackgroundTrackingState.fromMap(res);
      }
    } catch (e) {
      RouteEngineLogger.error('BackgroundTrackingEngine', 'Failed to fetch status', e);
    }
    return const BackgroundTrackingState(
      isRunning: false,
      permissionGranted: false,
      serviceRunning: false,
    );
  }
}
