import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/route.dart';
import '../core/logging/logger.dart';

/// Subsystem that persists active navigation session to recover from process restart.
class SessionPersistence {
  static const String _keyActiveRoute = 'flutter_map_navigator_active_route';
  static const String _keyIsNavigating = 'flutter_map_navigator_is_navigating';

  Future<void> saveNavigationSession(RouteResult route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveRoute, json.encode(route.toJson()));
      await prefs.setBool(_keyIsNavigating, true);
      RouteEngineLogger.info('SessionPersistence', 'Saved active navigation session.');
    } catch (e) {
      RouteEngineLogger.error('SessionPersistence', 'Failed to save session', e);
    }
  }

  Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsNavigating) ?? false;
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveRoute);
      await prefs.setBool(_keyIsNavigating, false);
      RouteEngineLogger.info('SessionPersistence', 'Cleared active navigation session.');
    } catch (e) {
      RouteEngineLogger.error('SessionPersistence', 'Failed to clear session', e);
    }
  }
}
