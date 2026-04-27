// M1-11 — proves SPEC §10 (dispose contract) at runtime: when the route
// containing a `@SolidState` signal is popped from `Navigator`, the emitted
// `signal.dispose()` actually fires. Static byte-equality of the emitted
// `dispose()` body is already covered by the M1-08 golden + idempotency
// suites; this test fences the runtime invariant that the call happens.
//
// Observation hook: `SignalBase<T>.onDispose(VoidCallback)` (declared in
// `solidart` and exported via `flutter_solidart`). This is the same public
// hook real user code uses, so the test exercises the SignalBase contract
// directly rather than a private subclass shim.
//
// `_ProbedCounterPage` mirrors the M1-05 generated `_CounterPageState` shape
// (see `example/lib/counter.dart`); the production `_CounterPageState` is
// library-private so the test cannot reach into it to register `onDispose`,
// hence the test-local mirror — same pattern M1-10 uses for `BuildTracker`.
//
// Forward compatibility: when M2-04 introduces the dispose-order golden for
// `Computed`, this same `onDispose` hook composes — register it on each
// signal, append a tag to a shared list, assert order. No new helper needed.

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Navigator pop disposes the signal exactly once', (
    tester,
  ) async {
    var disposeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ProbedCounterPage(
                      onSignalCreated: (signal) =>
                          signal.onDispose(() => disposeCount++),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      disposeCount,
      0,
      reason: 'Signal must be alive while the page is mounted',
    );
    expect(find.text('Counter is 0'), findsOneWidget);

    Navigator.of(tester.element(find.byType(_ProbedCounterPage))).pop();
    await tester.pumpAndSettle();

    expect(
      disposeCount,
      1,
      reason: 'Navigator pop must dispose the signal exactly once',
    );
  });
}

class _ProbedCounterPage extends StatefulWidget {
  const _ProbedCounterPage({required this.onSignalCreated});

  final void Function(SignalBase<int> signal) onSignalCreated;

  @override
  State<_ProbedCounterPage> createState() => _ProbedCounterPageState();
}

class _ProbedCounterPageState extends State<_ProbedCounterPage> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void initState() {
    super.initState();
    widget.onSignalCreated(counter);
  }

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text('Counter is ${counter.value}');
          },
        ),
      ),
    );
  }
}
