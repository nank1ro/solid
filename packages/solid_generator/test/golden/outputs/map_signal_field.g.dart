import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class MapProbe extends StatefulWidget {
  const MapProbe({super.key});

  @override
  State<MapProbe> createState() => _MapProbeState();
}

class _MapProbeState extends State<MapProbe> {
  final scores = MapSignal<String, int>(const {}, name: 'scores');

  @override
  void dispose() {
    scores.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('count: ${scores.length}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('has-a: ${scores.containsKey('a')}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('value-a: ${scores['a']}');
          },
        ),
        ElevatedButton(
          onPressed: () => scores['a'] = 1,
          child: const Text('set'),
        ),
        ElevatedButton(
          onPressed: () => scores.remove('a'),
          child: const Text('remove'),
        ),
      ],
    );
  }
}
