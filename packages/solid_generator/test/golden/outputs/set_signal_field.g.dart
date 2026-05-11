import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class SetProbe extends StatefulWidget {
  const SetProbe({super.key});

  @override
  State<SetProbe> createState() => _SetProbeState();
}

class _SetProbeState extends State<SetProbe> {
  final tags = SetSignal<int>(const {}, name: 'tags');

  @override
  void dispose() {
    tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('count: ${tags.length}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('has-1: ${tags.contains(1)}');
          },
        ),
        ElevatedButton(onPressed: () => tags.add(1), child: const Text('add')),
        ElevatedButton(
          onPressed: () => tags.remove(1),
          child: const Text('remove'),
        ),
      ],
    );
  }
}
