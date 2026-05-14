import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/units_controller.dart';
import '../domain/units.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @SolidEnvironment()
  late UnitsController units;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Temperature', style: TextStyle(fontSize: 12)),
          ),
          RadioListTile<TempUnit>(
            title: const Text('Celsius'),
            value: TempUnit.celsius,
            groupValue: units.tempUnit,
            onChanged: (v) {
              if (v != null) units.setTempUnit(v);
            },
          ),
          RadioListTile<TempUnit>(
            title: const Text('Fahrenheit'),
            value: TempUnit.fahrenheit,
            groupValue: units.tempUnit,
            onChanged: (v) {
              if (v != null) units.setTempUnit(v);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Wind speed', style: TextStyle(fontSize: 12)),
          ),
          RadioListTile<WindUnit>(
            title: const Text('km/h'),
            value: WindUnit.kmh,
            groupValue: units.windUnit,
            onChanged: (v) {
              if (v != null) units.setWindUnit(v);
            },
          ),
          RadioListTile<WindUnit>(
            title: const Text('mph'),
            value: WindUnit.mph,
            groupValue: units.windUnit,
            onChanged: (v) {
              if (v != null) units.setWindUnit(v);
            },
          ),
        ],
      ),
    );
  }
}
