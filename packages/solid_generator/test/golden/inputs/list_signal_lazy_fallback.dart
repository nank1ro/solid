// `late List<T> xs;` with no initializer must NOT produce a `ListSignal` —
// `ListSignal` has no `.lazy` constructor. The emitter falls back to
// `Signal<List<T>>.lazy(...)`, matching the scalar-late path. Chain
// reads still get `.value` rewriting under the plain-Signal path because
// `xs` is NOT in the collection-fields name set (a `Signal<List<T>>` does
// not expose `ListMixin` members directly).

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class LateListProbe extends StatelessWidget {
  LateListProbe({super.key});

  @SolidState()
  late List<int> xs;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
