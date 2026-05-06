// M8-01 — exercises the `.environment<T>()` textual-scan keep path.
//
// SPEC §9 bullet 4: `package:solid_annotations/...` survives in the output
// when the lowered code references the `.environment<T>()` extension. The
// extension call is user-written widget code that round-trips verbatim, so
// the builder cannot detect it via `RewriteResult.emitsDisposable` and
// instead scans the assembled body for `.environment\b`.
//
// Shape: an `@SolidState`-bearing `StatelessWidget` whose build body wraps
// a child in `.environment<Counter>(...)`. The Stateless→Stateful split
// runs (so `emitsDisposable` is FALSE), and the only reason
// `solid_annotations` survives in the output is the regex hit on the
// `.environment<` text inside `_AppState.build`. `Counter` is an
// unannotated plain class included only to give the extension a concrete
// type argument.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  int n = 0;
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
