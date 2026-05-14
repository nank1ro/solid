import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../api/weather_api.dart';
import '../controllers/units_controller.dart';
import '../domain/city.dart';
import '../domain/current_weather.dart';
import '../domain/forecast.dart';
import '../widgets/weather_icon.dart';

class CityDetailPage extends StatefulWidget {
  const CityDetailPage({super.key, required this.city});

  final City city;

  @override
  State<CityDetailPage> createState() => _CityDetailPageState();
}

class _CityDetailPageState extends State<CityDetailPage> {
  late final api = context.read<WeatherApi>();
  late final units = context.read<UnitsController>();
  late final current = Resource<CurrentWeather>(
    () => api.currentWeather(
      lat: widget.city.lat,
      lon: widget.city.lon,
      tempUnit: units.tempUnit.value,
      windUnit: units.windUnit.value,
    ),
    name: 'current',
  );
  late final hourly = Resource<Forecast>(
    () => api.hourlyForecast(
      lat: widget.city.lat,
      lon: widget.city.lon,
      tempUnit: units.tempUnit.value,
    ),
    name: 'hourly',
  );

  @override
  void dispose() {
    hourly.dispose();
    current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.city.name),
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
      body: SignalBuilder(
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CurrentSection(city: widget.city),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Failed: $e')),
                ),
              ),
              const SizedBox(height: 16),
              if (current().isRefreshing || hourly().isRefreshing)
                const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentSection extends StatefulWidget {
  const _CurrentSection({required this.city});

  final City city;

  @override
  State<_CurrentSection> createState() => __CurrentSectionState();
}

class __CurrentSectionState extends State<_CurrentSection> {
  late final units = context.read<UnitsController>();
  late final api = context.read<WeatherApi>();
  late final current = Resource<CurrentWeather>(
    () => api.currentWeather(
      lat: widget.city.lat,
      lon: widget.city.lon,
      tempUnit: units.tempUnit.value,
      windUnit: units.windUnit.value,
    ),
    name: 'current',
  );

  @override
  void dispose() {
    current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
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
      },
    );
  }
}
