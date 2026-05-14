import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../api/weather_api.dart';
import '../controllers/units_controller.dart';
import '../domain/city.dart';
import '../domain/current_weather.dart';
import '../domain/forecast.dart';
import '../widgets/weather_icon.dart';

class CityDetailPage extends StatelessWidget {
  CityDetailPage({super.key, required this.city});

  final City city;

  @SolidEnvironment()
  late WeatherApi api;

  @SolidEnvironment()
  late UnitsController units;

  @SolidQuery()
  Future<CurrentWeather> current() => api.currentWeather(
    lat: city.lat,
    lon: city.lon,
    tempUnit: units.tempUnit,
    windUnit: units.windUnit,
  );

  @SolidQuery()
  Future<Forecast> hourly() => api.hourlyForecast(
    lat: city.lat,
    lon: city.lon,
    tempUnit: units.tempUnit,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(city.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              current.refresh();
              hourly.refresh();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CurrentSection(city: city),
          const SizedBox(height: 24),
          const Text(
            'Next 24 hours',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: hourly().when(
              ready: (forecast) => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: forecast.hourly.length,
                itemBuilder: (context, index) {
                  final p = forecast.hourly[index];
                  return Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${p.time.hour.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(fontSize: 12),
                        ),
                        WeatherIcon(code: p.weatherCode, size: 28),
                        Text(units.formatTemp(p.temperature)),
                      ],
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed: $e')),
            ),
          ),
          const SizedBox(height: 16),
          if (current().isRefreshing || hourly().isRefreshing)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _CurrentSection extends StatelessWidget {
  const _CurrentSection({required this.city});

  final City city;

  @SolidEnvironment()
  late UnitsController units;

  @SolidEnvironment()
  late WeatherApi api;

  @SolidQuery()
  Future<CurrentWeather> current() => api.currentWeather(
    lat: city.lat,
    lon: city.lon,
    tempUnit: units.tempUnit,
    windUnit: units.windUnit,
  );

  @override
  Widget build(BuildContext context) {
    return current().when(
      ready: (w) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              WeatherIcon(code: w.weatherCode, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      units.formatTemp(w.temperature),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    Text('Wind ${units.formatWind(w.windSpeed)}'),
                    if (current().isRefreshing)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Refreshing…',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Current weather failed: $e'),
        ),
      ),
    );
  }
}
