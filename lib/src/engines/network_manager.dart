import 'dart:async';
import 'dart:io';

/// Subsystem for network connectivity checks and intelligent request retry.
class NetworkManager {
  Future<bool> isConnected() async {
    try {
      final result = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<T> retry<T>({
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await action();
      } catch (e) {
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(delay * attempts);
      }
    }
  }
}
