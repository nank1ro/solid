// Runtime fence for the cross-file `@SolidEnvironment` chain rewrite.
// `Counter` is declared in `source/cross_file_env/counter_controller.dart`
// and consumed by `CounterDisplay` in `source/cross_file_env/counter_display.dart`
// via `package:integration_tests/cross_file_env/...`. The two files are
// generated independently — the generator's resolver pass redirects the
// same-package `lib/` URI back to `source/` so the rewriter sees the
// pre-transformation `@SolidState` annotations even though Dart resolves
// the import to `lib/`.
//
// This test asserts that the SignalBuilder placements emitted in
// `counter_display.dart` actually subscribe to the live ListSignal/Signal
// in `counter_controller.dart` and rebuild on cross-class mutation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_tests/cross_file_env/counter_controller.dart';
import 'package:integration_tests/cross_file_env/counter_display.dart';
import 'package:solid_annotations/solid_annotations.dart';

void main() {
  testWidgets(
    'cross-file @SolidEnvironment: FAB tap rebuilds both scalar and '
    'collection consumers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const CounterDisplay().environment<Counter>(
            (_) => Counter(),
            dispose: (_, c) => c.dispose(),
          ),
        ),
      );

      expect(find.text('value: 0'), findsOneWidget);
      expect(find.text('history-len: 0'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        expect(
          find.text('value: ${i + 1}'),
          findsOneWidget,
          reason:
              'SignalBuilder on `counter.value` must rebuild on cross-FILE '
              'scalar signal mutation #${i + 1}',
        );
        expect(
          find.text('history-len: ${i + 1}'),
          findsOneWidget,
          reason:
              'SignalBuilder on `counter.history.length` must rebuild on '
              'cross-FILE ListSignal mutation #${i + 1} — the rewriter must '
              'have OMITTED `.value` between `counter.history` and `.length`',
        );
      }
    },
  );
}
