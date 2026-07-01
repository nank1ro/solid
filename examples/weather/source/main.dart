import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'api/weather_api.dart';
import 'controllers/cities_controller.dart';
import 'controllers/units_controller.dart';
import 'domain/city.dart';
import 'pages/home_page.dart';

void main() {
  runApp(
    const WeatherApp()
        .environment((_) => WeatherApi())
        .environment((_) => CitiesController(initial: City.samples))
        .environment((_) => UnitsController()),
  );
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}
