import 'package:flutter_tts/flutter_tts.dart';
import '../core/logging/logger.dart';

/// Subsystem for voice navigation and text-to-speech maneuver prompts.
class VoiceEngine {
  final FlutterTts _tts = FlutterTts();
  bool isEnabled = true;
  String _lastSpokenText = '';
  DateTime? _lastSpokenTimestamp;

  VoiceEngine() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      RouteEngineLogger.warning('VoiceEngine', 'Failed to initialize TTS engine: $e');
    }
  }

  Future<void> enable() async {
    isEnabled = true;
  }

  Future<void> disable() async {
    isEnabled = false;
    await stop();
  }

  Future<void> speak(String text) async {
    if (!isEnabled || text.trim().isEmpty) return;

    // Deduplicate repetitive speech within 5 seconds
    if (_lastSpokenText == text &&
        _lastSpokenTimestamp != null &&
        DateTime.now().difference(_lastSpokenTimestamp!).inSeconds < 5) {
      return;
    }

    _lastSpokenText = text;
    _lastSpokenTimestamp = DateTime.now();

    try {
      await _tts.speak(text);
    } catch (e) {
      RouteEngineLogger.error('VoiceEngine', 'TTS speak failed', e);
    }
  }

  void announceManeuver(String instruction, double distanceMeters) {
    if (!isEnabled) return;

    if (distanceMeters <= 30) {
      speak('Now, $instruction');
    } else if (distanceMeters <= 200 && distanceMeters > 150) {
      speak('In 200 meters, $instruction');
    } else if (distanceMeters <= 500 && distanceMeters > 450) {
      speak('In 500 meters, $instruction');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
