// Reads of a FOREIGN `flutter_solidart` signal — a hand-written `Signal<T>`
// the generator does not manage, injected rather than declared
// `@SolidState`. Both read sites must count as reactive dependencies:
//
//  * `GateModel.ready` lowers to a `Computed`. Its only dependency is the
//    injected signal, so before the type-aware rule it was rejected with
//    "getter 'ready' has no reactive dependencies".
//  * `GateBanner.build` gets a `SignalBuilder` wrap. Without it the widget
//    silently never rebuilds — the `.value` read subscribes nothing because
//    no tracking context is open around it.
//
// The remaining classes cover the other read FORMS of the same signal:
//
//  * `GateCall` — the callable form. `SignalBase.call() => value`, so
//    `complete()` observes exactly like `complete.value` and is the only
//    read in that build; it must still produce a wrap. `GateModel
//    .calledReady` reads the same callable form from a `Computed` body
//    instead of `build()` — see its own comment.
//  * `GateProbe` — `hasPreviousValue` and `Resource.state`, both of which
//    evaluate the underlying value internally and therefore observe.
//  * `GateOptOut` — the Section 6.4 `.untracked` spelling, which must NOT
//    be wrapped. (The read is left verbatim: rewriting a foreign
//    `.untracked` to solidart's `.untrackedValue` primitive is not
//    implemented, so the opt-out holds in `build()` — no tracking context is
//    opened around it — but not inside a `Computed` / `Effect` body.)
//
// `flutter_solidart` is not a dependency of the generator package, so
// `Signal` is unresolved in the golden sandbox and the rewriter falls back
// to matching the declared type's lexeme — the same two-tier rule
// `signalbase_typed.dart` exercises on the validator side. The resolved
// (`staticType`) tier and the multi-level `<env>.<signal>.value` receiver
// shape are fenced end-to-end by
// `packages/integration_tests/test/foreign_signal_test.dart`.
// ignore_for_file: undefined_class, undefined_identifier

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class GateModel {
  GateModel(this.complete);

  final Signal<bool?> complete;

  @SolidState()
  bool get ready => complete.value == true;

  // The callable form read from a `Computed` body (as opposed to `GateCall`
  // below, the same form read from `build()`): both must count as tracked
  // reads, driving different mechanisms (`Resource.source:`-style dep wiring
  // here vs. `SignalBuilder` placement there).
  @SolidState()
  bool get calledReady => complete() == true;
}

class GateBanner extends StatelessWidget {
  const GateBanner({required this.complete, super.key});

  final Signal<bool?> complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('gate'),
        Text('raw: ${complete.value}'),
      ],
    );
  }
}

class GateCall extends StatelessWidget {
  const GateCall({required this.complete, super.key});

  final Signal<bool?> complete;

  @override
  Widget build(BuildContext context) {
    return Text('call: ${complete()}');
  }
}

class GateProbe extends StatelessWidget {
  const GateProbe({
    required this.complete,
    required this.resource,
    super.key,
  });

  final Signal<bool?> complete;
  final Resource<bool?> resource;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('hadPrevious: ${complete.hasPreviousValue}'),
        Text('state: ${resource.state}'),
      ],
    );
  }
}

class GateOptOut extends StatelessWidget {
  const GateOptOut({required this.complete, super.key});

  final Signal<bool?> complete;

  @override
  Widget build(BuildContext context) {
    return Text('opt-out: ${complete.untracked.value}');
  }
}
