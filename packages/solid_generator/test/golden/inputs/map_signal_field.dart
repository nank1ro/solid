// Collection-typed `@SolidState` field of type `Map<K, V>` → `MapSignal<K, V>`.
// Same chain-access / mutation rules: `.length`, `.containsKey`, `[k]`, `[k]
// = v`, `.remove` resolve through `MapMixin<K, V>` on the signal directly.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class MapProbe extends StatelessWidget {
  MapProbe({super.key});

  @SolidState()
  Map<String, int> scores = const {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('count: ${scores.length}'),
        Text('has-a: ${scores.containsKey('a')}'),
        Text('value-a: ${scores['a']}'),
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
