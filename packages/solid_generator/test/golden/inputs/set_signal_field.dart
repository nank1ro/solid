// Collection-typed `@SolidState` field of type `Set<T>` → `SetSignal<T>`.
// Same chain-access / mutation rules as `ListSignal`: `.length`, `.contains`,
// `.add`, `.remove` resolve through `SetMixin<T>` on the signal directly.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class SetProbe extends StatelessWidget {
  SetProbe({super.key});

  @SolidState()
  Set<int> tags = const {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('count: ${tags.length}'),
        Text('has-1: ${tags.contains(1)}'),
        ElevatedButton(
          onPressed: () => tags.add(1),
          child: const Text('add'),
        ),
        ElevatedButton(
          onPressed: () => tags.remove(1),
          child: const Text('remove'),
        ),
      ],
    );
  }
}
