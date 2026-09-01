// Runtime fence for reads of a FOREIGN solidart signal — a hand-written
// `Signal` the generator does not manage, reached through an
// `@SolidEnvironment` receiver (`gate.complete.value`).
//
// Before the type-aware reactivity rule the generator counted only its own
// `@SolidState` / `@SolidQuery` members as reactive dependencies, so this
// shape produced a `build()` with NO `SignalBuilder` — the widget read the
// signal outside any tracking context and silently never rebuilt — and a
// `@SolidState` getter deriving from the same signal was rejected outright
// with "has no reactive dependencies".
//
// `Gate` and `GateView` are imported from the generator-lowered
// `package:integration_tests/foreign_signal_app.dart`, so the widget under
// test is the real production output of
// `packages/integration_tests/source/foreign_signal_app.dart`. Unlike the
// paired golden of the same shape, `flutter_solidart` resolves here, which
// makes this the coverage for the resolved-`staticType` tier and for the
// multi-level receiver the AST fallback cannot reach.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_tests/foreign_signal_app.dart';
import 'package:solid_annotations/solid_annotations.dart';

void main() {
  testWidgets('mutating a foreign Signal rebuilds both the direct build() '
      'read and the @SolidState getter derived from it', (tester) async {
    final gate = Gate();

    await tester.pumpWidget(
      MaterialApp(
        home: const GateView().environment<Gate>(
          (_) => gate,
          dispose: (_, g) => g.dispose(),
        ),
      ),
    );

    expect(find.text('raw: null'), findsOneWidget);
    expect(find.text('ready: false'), findsOneWidget);

    gate.complete.value = true;
    await tester.pump();

    expect(
      find.text('raw: true'),
      findsOneWidget,
      reason:
          'the direct `gate.complete.value` read in build() must be '
          'wrapped in a SignalBuilder',
    );
    expect(
      find.text('ready: true'),
      findsOneWidget,
      reason:
          'the @SolidState getter deriving from the foreign signal must '
          'lower to a Computed that re-runs',
    );
  });
}
