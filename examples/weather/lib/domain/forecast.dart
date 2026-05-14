class HourlyPoint {
  const HourlyPoint({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;
}

class Forecast {
  const Forecast({required this.hourly});

  factory Forecast.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temps = (hourly['temperature_2m'] as List).cast<num>();
    final codes = (hourly['weather_code'] as List).cast<int>();
    final points = <HourlyPoint>[];
    for (var i = 0; i < times.length && i < 24; i++) {
      points.add(
        HourlyPoint(
          time: DateTime.parse(times[i]),
          temperature: temps[i].toDouble(),
          weatherCode: codes[i],
        ),
      );
    }
    return Forecast(hourly: points);
  }

  final List<HourlyPoint> hourly;
}
