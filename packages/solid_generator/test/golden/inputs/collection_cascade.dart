// Cascade chain reads on collection signals must NOT receive a `.value`
// insertion between the receiver identifier and the cascade sections —
// `CascadeExpression.target` is the collection identifier, so
// `_isChainPrefix` matches and the rewriter skips the append. The cascade
// sections themselves (`..add(7)`, `..['x'] = 1`) target the cascade's
// implicit receiver, which is the underlying signal — and `ListSignal` /
// `MapSignal` mutators notify subscribers from inside the mixin.

import 'package:solid_annotations/solid_annotations.dart';

class CascadeProbe {
  @SolidState()
  List<int> xs = const [];

  @SolidState()
  Map<String, int> counts = const {};

  void seed() {
    xs
      ..add(7)
      ..add(8)
      ..sort();
    counts
      ..['x'] = 1
      ..['y'] = 2;
  }
}
