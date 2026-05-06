// SPEC §14 item 7 clause (a): a `this.<name>` FieldFormalParameter on a
// `final` field is const-safe and triggers `const` on the lowered ctor.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Greeter extends StatelessWidget {
  Greeter({super.key, required this.label});

  final String label;

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$label $counter');
  }
}
