// A `Map<K, V>` field initialised with a `const {…}` literal must be
// rejected at build time: the lowered MapSignal would forward writes to
// the unmodifiable underlying map and throw `UnsupportedError` on the
// first mutation. Regression for the user-reported runtime bug.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class MapMutate extends StatelessWidget {
  MapMutate({super.key});

  @SolidState()
  Map<String, int> items = const {'a': 1, 'b': 2};

  @override
  Widget build(BuildContext context) => const Placeholder();
}
