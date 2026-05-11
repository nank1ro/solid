import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class ListProbe extends StatefulWidget {
  const ListProbe({super.key});

  @override
  State<ListProbe> createState() => _ListProbeState();
}

class _ListProbeState extends State<ListProbe> {
  final xs = ListSignal<int>(const [], name: 'xs');

  @override
  void dispose() {
    xs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('length: ${xs.length}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('first: ${xs[0]}');
          },
        ),
        ElevatedButton(onPressed: () => xs.add(1), child: const Text('add')),
        ElevatedButton(onPressed: () => xs[0] = 5, child: const Text('set')),
      ],
    );
  }
}
