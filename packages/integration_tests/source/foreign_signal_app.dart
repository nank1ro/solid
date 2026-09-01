// End-to-end source for the foreign-signal reactivity test: a `Gate` holding
// a hand-written `flutter_solidart` `Signal` (NOT `@SolidState` — the
// generator does not manage it) reached through an `@SolidEnvironment`
// receiver.
//
// Both read sites are covered: `build()` reads `gate.complete.value`
// directly and must get a `SignalBuilder` wrap, and the `@SolidState` getter
// `ready` derives from the same foreign signal and must lower to a
// `Computed`. Unlike the golden fixture of the same shape, `flutter_solidart`
// resolves here, so this exercises the resolved-`staticType` tier and the
// multi-level `<env>.<signal>.value` receiver the AST fallback cannot reach.

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Gate {
  /// Tri-state: `null` means "not known yet".
  final Signal<bool?> complete = Signal(null);

  // `complete` is hand-written, so the generator synthesizes no disposal for
  // it — the owner disposes it, and the provider scope's `dispose:` callback
  // calls through to here.
  void dispose() => complete.dispose();
}

class GateView extends StatelessWidget {
  GateView({super.key});

  @SolidEnvironment()
  late Gate gate;

  @SolidState()
  bool get ready => gate.complete.value ?? false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('raw: ${gate.complete.value}'),
        Text('ready: $ready'),
      ],
    );
  }
}
