// `late List<T> xs;` / `late Set<T> tags;` / `late Map<K, V> hits;`
// (non-nullable, no initializer) all lower to their respective collection
// signals — the `late` modifier is irrelevant for collection signals
// because the reference is final and mutation happens through the
// `ListMixin` / `SetMixin` / `MapMixin` methods on the underlying
// collection. The emitted ctors use empty literal defaults
// (`const <T>[]`, `const <T>{}`, `const <K, V>{}`); the source `late`
// modifier is preserved on each emitted field so signal construction
// still defers to first access.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class LateCollectionProbe extends StatelessWidget {
  LateCollectionProbe({super.key});

  @SolidState()
  late List<int> xs;

  @SolidState()
  late Set<String> tags;

  @SolidState()
  late Map<String, int> hits;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
