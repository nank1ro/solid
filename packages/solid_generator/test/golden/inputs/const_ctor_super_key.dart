// Canonical case: a `Widget({super.key})` ctor with no body and no init
// list, on a class whose only mutable instance fields are `@SolidState`
// (moved off the widget by the class split). The rewritten StatefulWidget
// half is const-eligible — the generator prefixes `const` on emit.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Widget1 extends StatelessWidget {
  Widget1({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$counter');
  }
}
