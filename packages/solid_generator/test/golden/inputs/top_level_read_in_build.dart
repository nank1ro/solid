// A top-level read at the build method's statement scope (no enclosing
// widget candidate) used as a local variable in a return expression. The
// generator must synthesize an outer `SignalBuilder` around the entire
// build body — without it, the read fires once and never re-subscribes
// (silent reactivity loss; see SPEC §7.1 unanchored-reads case).

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class GreetingPage extends StatelessWidget {
  GreetingPage({super.key});

  @SolidState()
  String name = 'world';

  @override
  Widget build(BuildContext context) {
    final n = name;
    return Text('hello $n');
  }
}
