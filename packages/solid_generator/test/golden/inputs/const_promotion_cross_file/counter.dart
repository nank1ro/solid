// `CounterPage` is the Solid-lowered widget used by `main.dart`. The class
// gains a `const` constructor in the lowered output (Section 14 item 7), and
// that emitted name is the one `_emitCtors` contributes to the call-site
// `const` pass for cross-file consumers — `main.dart` calls
// `runApp(MaterialApp(home: CounterPage()))` and expects the outer
// `MaterialApp` to be promoted because `CounterPage()` is recognized as
// const-evaluable.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState()
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$count');
  }
}
