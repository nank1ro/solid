import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/units_controller.dart';
import '../domain/units.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final units = context.read<UnitsController>();

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
          SignalBuilder(
            builder: (context, child) {
              return RadioListTile<TempUnit>(
                title: const Text('Celsius'),
                value: TempUnit.celsius,
                groupValue: units.tempUnit.value,
                onChanged: (v) {
                  if (v != null) units.setTempUnit(v);
                },
              );
            },
          ),
          SignalBuilder(
            builder: (context, child) {
              return RadioListTile<TempUnit>(
                title: const Text('Fahrenheit'),
                value: TempUnit.fahrenheit,
                groupValue: units.tempUnit.value,
                onChanged: (v) {
                  if (v != null) units.setTempUnit(v);
                },
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Wind speed', style: TextStyle(fontSize: 12)),
          ),
          SignalBuilder(
            builder: (context, child) {
              return RadioListTile<WindUnit>(
                title: const Text('km/h'),
                value: WindUnit.kmh,
                groupValue: units.windUnit.value,
                onChanged: (v) {
                  if (v != null) units.setWindUnit(v);
                },
              );
            },
          ),
          SignalBuilder(
            builder: (context, child) {
              return RadioListTile<WindUnit>(
                title: const Text('mph'),
                value: WindUnit.mph,
                groupValue: units.windUnit.value,
                onChanged: (v) {
                  if (v != null) units.setWindUnit(v);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
