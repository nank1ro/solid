import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../api/weather_api.dart';
import '../controllers/cities_controller.dart';
import '../controllers/units_controller.dart';
import '../domain/city.dart';
import '../domain/current_weather.dart';
import '../pages/city_detail_page.dart';
import 'weather_icon.dart';

class CityCard extends StatelessWidget {
  CityCard({super.key, required this.city});

  final City city;

  @SolidEnvironment()
  late WeatherApi api;

  @SolidEnvironment()
  late UnitsController units;

  @SolidEnvironment()
  late CitiesController citiesController;

  @SolidQuery()
  Future<CurrentWeather> weather() => api.currentWeather(
    lat: city.lat,
    lon: city.lon,
    tempUnit: units.tempUnit,
    windUnit: units.windUnit,
  );

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${city.lat},${city.lon}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => citiesController.remove(city),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CityDetailPage(city: city),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: weather().when(
              ready: (w) => Row(
                children: [
                  WeatherIcon(code: w.weatherCode, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          city.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        units.formatTemp(w.temperature),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        units.formatWind(w.windSpeed),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => Row(
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(city.name),
                ],
              ),
              error: (e, _) => Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Failed: $e',
                          style: const TextStyle(color: Colors.red),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
