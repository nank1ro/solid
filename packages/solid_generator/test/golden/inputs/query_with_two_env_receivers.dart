// A `@SolidQuery` body whose deps come from TWO DIFFERENT
// `@SolidEnvironment`-injected receivers (`auth.userId` + `filter.factor`)
// folds both pairs into the synthesized Record-Computed source. Each
// `(envField, signalName)` pair appears in source-first-appearance order and
// the Computed Record carries one element per pair.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Auth {
  @SolidState()
  int userId = 0;
}

class Filter {
  @SolidState()
  int factor = 1;
}

class ValueCard extends StatelessWidget {
  ValueCard({super.key});

  @SolidEnvironment()
  late Auth auth;

  @SolidEnvironment()
  late Filter filter;

  @SolidQuery()
  Future<int> fetchValue() async => auth.userId * filter.factor;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
