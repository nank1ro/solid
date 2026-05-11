// Exercises the `.environment<T>()` textual-scan keep path.
//
// `package:solid_annotations/...` survives in the output when the lowered
// code references the `.environment<T>()` extension. The
// extension call is user-written widget code that round-trips verbatim, so
// the builder cannot detect it via `RewriteResult.emitsDisposable` and
// instead scans the assembled body for `.environment\b`.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  int n = 0;

  void dispose() {}
}

class App extends StatelessWidget {
  App({super.key});

  @SolidState()
  int n = 0;

  @override
  Widget build(BuildContext context) {
    return const Placeholder().environment<Counter>((_) => Counter());
  }
}
