// Collection-typed `@SolidState` field on a `StatelessWidget`. The emitter
// produces `ListSignal<int>` (not `Signal<List<int>>`), and the value
// rewriter SKIPS `.value` insertion on chain reads (`xs.length`,
// `xs[i]`) because `ListSignal<T>` exposes the full `ListMixin<T>` API
// directly. Direct mutations (`xs.add`, `xs[i] = v`) are emitted verbatim
// (`ListSignal` notifies subscribers on each call). The pure-write
// rewrite (`xs = ...`) still goes through `.value =`.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ListProbe extends StatelessWidget {
  ListProbe({super.key});

  @SolidState()
  List<int> xs = const [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('length: ${xs.length}'),
        Text('first: ${xs[0]}'),
        ElevatedButton(
          onPressed: () => xs.add(1),
          child: const Text('add'),
        ),
        ElevatedButton(
          onPressed: () => xs[0] = 5,
          child: const Text('set'),
        ),
      ],
    );
  }
}
