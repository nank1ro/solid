// A `@SolidQuery` body that reads a cross-class collection-typed Signal
// (`ListSignal` via `@SolidState List<int> items`). Pins the current
// behavior: cross-class collection deps are NOT recorded for the
// `source:` argument synthesis (`value_rewriter.dart`'s deferred path —
// `isEnvReceiver && !isCollection` gate excludes collection fields), so
// the emitted `Resource<T>.stream(...)` has no `source:` argument. Auto-
// tracking still happens at runtime via the ListSignal mixin, so the
// stream re-fetches on widget rebuild that pulls a new `channelId`-like
// constructor arg, but NOT on collection mutations alone.
//
// When the resolved-AST migration lands, this golden's expected behavior
// may change (the source-synthesis path could become aware of collection
// deps). Keep this golden in sync with whichever semantics the generator
// commits to.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Store {
  @SolidState()
  List<int> items = [];
}

class Reader extends StatelessWidget {
  Reader({super.key});

  @SolidEnvironment()
  late Store store;

  @SolidQuery()
  Stream<int> watchCount() async* {
    yield store.items.length;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
