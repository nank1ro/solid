// Cross-file `@SolidEnvironment` consumer whose `@SolidQuery` body reads a
// cross-class signal whose declared type (`Unit`) lives in a file the source
// does NOT import. The synthesized Record-Computed `Computed<(int, Unit)>`
// names `Unit` in the lib output; the generator must inject the
// `package:a/.../types.dart` import.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controllers.dart';

class Display extends StatelessWidget {
  Display({super.key});

  @SolidEnvironment()
  late Settings settings;

  @SolidState()
  int seed = 0;

  @SolidQuery()
  Future<String> q() async => '$seed-${settings.unit}';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
