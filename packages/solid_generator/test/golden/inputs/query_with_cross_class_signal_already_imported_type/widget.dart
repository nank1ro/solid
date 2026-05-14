// Consumer source imports `types.dart` directly. The synthesized import
// must NOT duplicate the existing source-side import — dedup against the
// source's import URI list.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controllers.dart';
import 'types.dart';

class Display extends StatelessWidget {
  Display({super.key});

  @SolidEnvironment()
  late Settings settings;

  @SolidState()
  int seed = 0;

  @SolidQuery()
  Future<String> q() async => '$seed-${settings.unit}-${Unit.b}';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
