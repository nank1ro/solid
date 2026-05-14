import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/city.dart';
import '../domain/current_weather.dart';
import '../domain/forecast.dart';
import '../domain/units.dart';

class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void dispose() {
    _client.close();
  }

  static final Uri _geocodeBase = Uri.parse(
    'https://geocoding-api.open-meteo.com/v1/search',
  );
  static final Uri _forecastBase = Uri.parse(
    'https://api.open-meteo.com/v1/forecast',
  );

  Future<List<City>> geocode(String query) async {
    if (query.trim().isEmpty) return const [];
    final uri = _geocodeBase.replace(
      queryParameters: {
        'name': query.trim(),
        'count': '10',
        'language': 'en',
        'format': 'json',
      },
    );
    debugPrint('[WeatherApi] geocode → $uri');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Geocoding failed: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? const [];
    return results
        .cast<Map<String, dynamic>>()
        .map(City.fromGeocodingJson)
        .toList();
  }

  Future<CurrentWeather> currentWeather({
    required double lat,
    required double lon,
    required TempUnit tempUnit,
    required WindUnit windUnit,
  }) async {
    final uri = _forecastBase.replace(
      queryParameters: {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current': 'temperature_2m,wind_speed_10m,weather_code',
        'temperature_unit': tempUnit.apiValue,
        'wind_speed_unit': windUnit.apiValue,
      },
    );
    debugPrint('[WeatherApi] currentWeather → $uri');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Forecast failed: HTTP ${res.statusCode}');
    }
    return CurrentWeather.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<Forecast> hourlyForecast({
    required double lat,
    required double lon,
    required TempUnit tempUnit,
  }) async {
    final uri = _forecastBase.replace(
      queryParameters: {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'hourly': 'temperature_2m,weather_code',
        'temperature_unit': tempUnit.apiValue,
        'forecast_days': '1',
      },
    );
    debugPrint('[WeatherApi] hourlyForecast → $uri');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Hourly forecast failed: HTTP ${res.statusCode}');
    }
    return Forecast.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
