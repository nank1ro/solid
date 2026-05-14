class City {
  const City({
    required this.name,
    required this.country,
    required this.admin1,
    required this.lat,
    required this.lon,
  });

  factory City.fromGeocodingJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String,
      country: json['country'] as String?,
      admin1: json['admin1'] as String?,
      lat: (json['latitude'] as num).toDouble(),
      lon: (json['longitude'] as num).toDouble(),
    );
  }

  final String name;
  final String? country;
  final String? admin1;
  final double lat;
  final double lon;

  String get subtitle {
    final parts = [admin1, country].where((s) => s != null && s.isNotEmpty);
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lon == other.lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  static const List<City> samples = [
    City(
      name: 'Berlin',
      country: 'Germany',
      admin1: 'Berlin',
      lat: 52.52,
      lon: 13.41,
    ),
    City(
      name: 'Tokyo',
      country: 'Japan',
      admin1: 'Tokyo',
      lat: 35.6762,
      lon: 139.6503,
    ),
    City(
      name: 'San Francisco',
      country: 'United States',
      admin1: 'California',
      lat: 37.7749,
      lon: -122.4194,
    ),
  ];
}
