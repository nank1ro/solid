import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'api/weather_api.dart';
import 'controllers/cities_controller.dart';
import 'controllers/units_controller.dart';
import 'domain/city.dart';
import 'pages/home_page.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(
    const WeatherApp()
        .environment(
          (_) => WeatherApi(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => CitiesController(initial: City.samples),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => UnitsController(),
          dispose: (context, provider) => provider.dispose(),
        ),
  );
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}
