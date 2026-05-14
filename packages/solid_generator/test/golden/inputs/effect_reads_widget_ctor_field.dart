// `@SolidEffect` on a `StatelessWidget` whose body reads BOTH a widget-bound
// constructor field and a `@SolidState` field. The lowered Effect closure
// must read the ctor field through `widget.<name>`.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class TempLogger extends StatelessWidget {
  TempLogger({super.key, required this.label});

  final String label;

  @SolidState()
  double celsius = 0;

  @SolidEffect()
  void logTemp() {
    debugPrint('$label is at $celsius');
  }

  @override
  Widget build(BuildContext context) => Text('$celsius');
}
