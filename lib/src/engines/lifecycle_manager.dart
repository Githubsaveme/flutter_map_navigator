import 'package:flutter/widgets.dart';
import '../core/logging/logger.dart';

typedef LifecycleCallback = void Function(AppLifecycleState state);

/// Subsystem that monitors app lifecycle transitions (paused, resumed, detached).
class LifecycleManager with WidgetsBindingObserver {
  final List<LifecycleCallback> _listeners = [];
  AppLifecycleState _lastState = AppLifecycleState.resumed;

  LifecycleManager() {
    WidgetsBinding.instance.addObserver(this);
  }

  AppLifecycleState get lastState => _lastState;

  void addListener(LifecycleCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(LifecycleCallback callback) {
    _listeners.remove(callback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastState = state;
    RouteEngineLogger.info('LifecycleManager', 'App lifecycle changed to: $state');
    for (final listener in _listeners) {
      listener(state);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listeners.clear();
  }
}
