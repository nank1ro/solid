import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  late final forecast = Resource<String>(
    () async => 'temp@${widget.lat},${widget.lon}',
    name: 'forecast',
  );

  @override
  void dispose() {
    forecast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${widget.lat},${widget.lon}');
}
