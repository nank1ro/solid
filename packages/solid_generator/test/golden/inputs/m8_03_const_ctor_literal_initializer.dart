// SPEC §14 item 7 clause (c) keep-path: a named ctor whose initializer
// list contains only `ConstructorFieldInitializer` entries with literal
// RHS values is const-eligible. `: label = 'Named'` is a SimpleStringLiteral
// — `const Greeter.named({super.key}) : label = 'Named'` is valid Dart and
// the generator emits `const`.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Greeter extends StatelessWidget {
  Greeter.named({super.key}) : label = 'Named';

  final String label;

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) => Text('$label $counter');
}
