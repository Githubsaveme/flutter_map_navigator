import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models/search_result.dart';
import '../core/logging/logger.dart';

abstract class SearchProvider {
  Future<List<SearchResult>> query(String queryText);
  Future<List<SearchResult>> suggestions(String queryText);
}

/// Free, open-source Nominatim OpenStreetMap Search Provider.
class NominatimSearchProvider implements SearchProvider {
  final String userAgent;
  final http.Client _httpClient;

  NominatimSearchProvider({
    this.userAgent = 'FlutterMapNavigator/1.0',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<List<SearchResult>> query(String queryText) async {
    if (queryText.trim().isEmpty) return [];

    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(queryText)}&format=json&addressdetails=1&limit=10');
    try {
      final response = await _httpClient.get(url, headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final list = json.decode(response.body) as List<dynamic>;
      return list.map((item) => SearchResult.fromNominatimJson(item as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      RouteEngineLogger.error('NominatimSearchProvider', 'Search query failed', e, stack);
      return [];
    }
  }

  @override
  Future<List<SearchResult>> suggestions(String queryText) {
    return query(queryText);
  }
}

class SearchEngine {
  SearchProvider provider;

  SearchEngine({SearchProvider? provider}) : provider = provider ?? NominatimSearchProvider();

  Future<List<SearchResult>> query(String queryText) => provider.query(queryText);
  Future<List<SearchResult>> suggestions(String queryText) => provider.suggestions(queryText);
}
