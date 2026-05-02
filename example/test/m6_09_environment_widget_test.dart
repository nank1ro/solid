// M6-09 — fences SPEC §3.6 (`.environment<T>()` extension, source-side
// `dispose()` stub requirement), §7 (`SignalBuilder` placement on cross-class
// chain read), and §10 (synthesized reactive disposal merged into the user's
// empty `dispose()` body for plain classes) at runtime.
//
// `Counter` and `CounterDisplay` are imported from the generator-lowered
// `package:example/m6_09_environment_app.dart` — this is the first widget
// test that runs against generated `lib/` code (M1-10 / M3-04 / M4-07 / M5-07
// all inline a test-local mirror of the lowered shape). The widget under
// test is therefore the actual production output of the source app at
// `example/source/m6_09_environment_app.dart`.
//
// The dispose assertion uses a closure-counted `dispose:` callback (rather
// than `Counter.value.onDispose`) because the M6-09 acceptance criterion is
// specifically the user-passed callback firing exactly once on provider
// teardown. The internal Signal disposal is fenced by M6-02's user-dispose
// merge golden + M1-11's runtime onDispose test.

import 'dart:async';

import 'package:example/m6_09_environment_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solid_annotations/solid_annotations.dart';

void main() {
  testWidgets('FAB tap mutates provided Counter and rebuilds consumer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const CounterDisplay().environment<Counter>(
          (_) => Counter(),
          dispose: (_, c) => c.dispose(),
        ),
      ),
    );

    expect(find.text('Counter is 0'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(
        find.text('Counter is ${i + 1}'),
        findsOneWidget,
        reason:
            'SignalBuilder must rebuild on cross-class signal mutation '
            '#${i + 1}',
      );
    }
  });

  testWidgets(
    'Tearing down provider scope invokes user dispose callback exactly once',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      var disposeCallbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );

      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const CounterDisplay().environment<Counter>(
              (_) => Counter(),
              dispose: (_, c) {
                disposeCallbackCount++;
                c.dispose();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        disposeCallbackCount,
        0,
        reason: 'Counter alive while page mounted',
      );

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        disposeCallbackCount,
        1,
        reason:
            'Navigator pop tears down the .environment Provider, invoking '
            'its user-passed dispose callback exactly once',
      );
    },
  );
}
