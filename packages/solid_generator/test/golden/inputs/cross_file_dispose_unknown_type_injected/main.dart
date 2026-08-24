// Tier 4 ("unknown") regression fixture: `main.dart` carries a `@Solid*`
// annotation (`Counter`), forcing the main lowering path — no resolver is
// available when `addProviderDisposeAtCallSites` runs. `AuthRepository`
// (imported from `repo.dart`) is a plain, dispose-less class, but it is
// declared in ANOTHER file: this checker's same-file AST tier
// (`_hasDisposeInSameUnit`) never sees it, and it never enters the
// `classRegistry` (only `@Solid*`-annotated cross-file types do — see
// `_populateCrossFileTypes`). Per the documented tier-4 default, the
// checker cannot prove `AuthRepository` plain here, so it injects
// `dispose:` anyway — the pre-type-aware, loud-failure-by-default behavior
// Ale's ruling explicitly accepts for anything beyond same-file: the
// opt-out is an explicit `dispose: null` at the call site.
// ignore_for_file: unreachable_from_main, prefer_const_constructors_in_immutables

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'repo.dart';

class Counter {
  @SolidState()
  int value = 0;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(const HomePage().environment<AuthRepository>((_) => AuthRepository()));
}
