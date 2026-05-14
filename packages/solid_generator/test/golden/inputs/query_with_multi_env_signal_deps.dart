// A `@SolidQuery` body that reads TWO OR MORE cross-class `@SolidState` signals
// through an `@SolidEnvironment`-injected receiver synthesizes a Record-Computed
// source field whose tuple mirrors the body's reads. Each cross-class element
// contributes element type `T` (looked up from the env-field's class) and read
// expression `<envField>.<signalName>.value`. Mirrors `query_with_multi_signal_deps`
// but the deps live on a sibling class reached through an `@SolidEnvironment`
// field — the exact shape that motivated the fix in `examples/weather`.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Settings {
  @SolidState()
  int factor = 1;

  @SolidState()
  String? prefix;
}

class ValueCard extends StatelessWidget {
  ValueCard({super.key});

  @SolidEnvironment()
  late Settings settings;

  @SolidQuery()
  Future<String> fetchValue() async =>
      '${settings.prefix ?? ''}${10 * settings.factor}';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
