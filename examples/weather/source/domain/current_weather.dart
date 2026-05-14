class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.time,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    return CurrentWeather(
      temperature: (current['temperature_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      time: DateTime.parse(current['time'] as String),
    );
  }

  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final DateTime time;
}
