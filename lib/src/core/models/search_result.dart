import 'package:latlong2/latlong.dart';

/// Represents a search or geocoding result item.
class SearchResult {
  final String title;
  final String subtitle;
  final LatLng position;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postcode;
  final Map<String, dynamic> raw;

  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.position,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postcode,
    this.raw = const {},
  });

  factory SearchResult.fromNominatimJson(Map<String, dynamic> json) {
    final lat = double.parse(json['lat'].toString());
    final lon = double.parse(json['lon'].toString());
    final displayName = json['display_name'] as String? ?? '';
    final addressMap = json['address'] as Map<String, dynamic>? ?? {};

    return SearchResult(
      title: displayName.split(',').first.trim(),
      subtitle: displayName,
      position: LatLng(lat, lon),
      address: displayName,
      city: addressMap['city'] ?? addressMap['town'] ?? addressMap['village'],
      state: addressMap['state'],
      country: addressMap['country'],
      postcode: addressMap['postcode'],
      raw: json,
    );
  }
}
