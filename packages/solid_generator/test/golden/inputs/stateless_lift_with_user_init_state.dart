// A `StatelessWidget` with `@SolidEffect` plus a user-authored block-body
// `initState()`. Before F-3 the user `initState` was dropped and only the
// synthesized one (with `super.initState(); <effectName>;`) appeared. After
// F-3 the merge splices the Effect materialization read after the user's
// `super.initState();` call but keeps the user statements (here a
// `debugPrint('init')`) afterwards.
//
// Mirror of `effect_on_state_class` for the stateless-lift path.
//
// `print` is the canonical Effect side-effect example.
// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Boot extends StatelessWidget {
  Boot({super.key});

  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('Counter: $counter');
  }

  void initState() {
    debugPrint('init');
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
