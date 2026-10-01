import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/models/search_result.dart';
import '../core/logging/logger.dart';

/// Subsystem for forward and reverse geocoding.
class GeocodingEngine {
  final String userAgent;
  final http.Client _httpClient;

  GeocodingEngine({
    this.userAgent = 'FlutterMapNavigator/1.0',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Forward geocoding: converts address string to location coordinates.
  Future<List<SearchResult>> forward(String address) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&addressdetails=1&limit=5');
    try {
      final response = await _httpClient.get(url, headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final list = json.decode(response.body) as List<dynamic>;
      return list.map((item) => SearchResult.fromNominatimJson(item as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      RouteEngineLogger.error('GeocodingEngine', 'Forward geocoding failed', e, stack);
      return [];
    }
  }

  /// Reverse geocoding: converts LatLng coordinates to human-readable address.
  Future<SearchResult?> reverse(LatLng position) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1');
    try {
      final response = await _httpClient.get(url, headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final map = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromNominatimJson(map);
    } catch (e, stack) {
      RouteEngineLogger.error('GeocodingEngine', 'Reverse geocoding failed', e, stack);
      return null;
    }
  }
}
