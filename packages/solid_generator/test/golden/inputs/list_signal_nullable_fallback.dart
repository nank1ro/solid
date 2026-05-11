// `List<T>?` (nullable) must NOT produce a `ListSignal` — `ListSignal`
// rejects null. The emitter falls back to `Signal<List<T>?>(null, ...)`,
// matching the nullable-scalar path.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class NullableListProbe extends StatelessWidget {
  NullableListProbe({super.key});

  @SolidState()
  List<int>? xs;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
