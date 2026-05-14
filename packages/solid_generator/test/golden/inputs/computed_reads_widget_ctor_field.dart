// `@SolidState` getter on a `StatelessWidget` whose body reads BOTH a
// widget-bound constructor field and a `@SolidState` field. The lowered
// Computed must read the ctor field through `widget.<name>` because the
// getter lives on the State class, not the Widget.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class TempBadge extends StatelessWidget {
  TempBadge({super.key, required this.label});

  final String label;

  @SolidState()
  double celsius = 0;

  @SolidState()
  String get display => '$label ${celsius.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) => Text(display);
}
