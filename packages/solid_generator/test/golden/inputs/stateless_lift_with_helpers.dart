// A `StatelessWidget` with `@SolidState` plus a private helper method and a
// user-authored block-body `dispose()`. Before F-3, the helper was silently
// dropped and the user `dispose()` was overwritten by the synthesized one.
// This golden pins that:
//   * the helper survives on the lifted `_FooState`,
//   * the user `dispose()` body merges with the reactive teardowns (reactive
//     calls first, user statements after).
//
// `Timer` is the canonical non-Solid disposable that motivates this fix:
// without preservation of both the helper and the `dispose()` body, the
// Timer would leak after the widget unmounts.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class WithHelper extends StatelessWidget {
  WithHelper({super.key});

  @SolidState()
  int counter = 0;

  Timer? _timer;

  String _format(int x) => 'x: $x';

  void dispose() {
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) => Text(_format(counter));
}
