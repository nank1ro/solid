import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../api/weather_api.dart';
import '../controllers/cities_controller.dart';
import '../controllers/units_controller.dart';
import '../domain/city.dart';
import '../domain/current_weather.dart';
import '../domain/units.dart';
import '../pages/city_detail_page.dart';
import 'weather_icon.dart';

class CityCard extends StatefulWidget {
  const CityCard({super.key, required this.city});

  final City city;

  @override
  State<CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<CityCard> {
  late final api = context.read<WeatherApi>();
  late final units = context.read<UnitsController>();
  late final citiesController = context.read<CitiesController>();
  late final _weatherSource = Computed<(TempUnit, WindUnit)>(
    () => (units.tempUnit.value, units.windUnit.value),
    name: '_weatherSource',
  );
  late final weather = Resource<CurrentWeather>(
    () => api.currentWeather(
      lat: widget.city.lat,
      lon: widget.city.lon,
      tempUnit: units.tempUnit.value,
      windUnit: units.windUnit.value,
    ),
    source: _weatherSource,
    name: 'weather',
  );

  @override
  void dispose() {
    weather.dispose();
    _weatherSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${widget.city.lat},${widget.city.lon}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => citiesController.remove(widget.city),
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
                builder: (_) => CityDetailPage(city: widget.city),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SignalBuilder(
              builder: (context, child) {
                return weather().when(
                  ready: (w) => Row(
                    children: [
                      WeatherIcon(code: w.weatherCode, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.city.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              widget.city.subtitle,
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
                      Text(widget.city.name),
                    ],
                  ),
                  error: (e, _) => Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.city.name,
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
