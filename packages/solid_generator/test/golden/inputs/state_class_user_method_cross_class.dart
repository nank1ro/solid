// User-authored method on a State<X> subclass that writes to a cross-class
// @SolidState field via an @SolidEnvironment-injected controller. The
// rewriter must rewrite `ctrl.name = 'd'` to `ctrl.name.value = 'd'` the same
// way it does for `build`/Effect/Query bodies. Mirror of
// `cross_class_value_read` for the user-method position on State<X>.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class SomeController {
  @SolidState()
  String name = '';
}

class Resetter extends StatefulWidget {
  const Resetter({super.key});

  @override
  State<Resetter> createState() => _ResetterState();
}

class _ResetterState extends State<Resetter> {
  @SolidEnvironment()
  late SomeController ctrl;

  void reset() {
    ctrl.name = 'default';
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
