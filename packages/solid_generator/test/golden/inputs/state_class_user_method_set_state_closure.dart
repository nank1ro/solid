// User method on a State<X> subclass wraps a Signal write in setState(() {
// ... }). The value-rewriter must descend through the FunctionExpression
// (setState's argument is a callback but NOT an `on*` user-interaction
// callback that suppresses tracking) and rewrite the closure body's
// assignment to `name.value = '...'`. The `setState` call itself is
// preserved verbatim.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Resetter extends StatefulWidget {
  const Resetter({super.key});

  @override
  State<Resetter> createState() => _ResetterState();
}

class _ResetterState extends State<Resetter> {
  @SolidState()
  String name = 'init';

  void reset() {
    setState(() {
      name = 'default';
    });
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
