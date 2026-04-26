// M1-10 — proves SPEC §7 (SignalBuilder placement) at runtime: a FAB tap
// rebuilds only the `Text` subtree wrapped by `SignalBuilder`; the sibling
// `Icon` does not. `_TrackedCounterPage` mirrors the M1-05 generated
// `_CounterPageState` (see `example/lib/counter.dart`) but wraps the `Text`
// and `Icon` leaves in `BuildTracker` — `BuildTracker` cannot be inserted
// into the generated output without breaking the M1-05 golden, and the
// generator's byte-equality is already covered by the golden + idempotency
// suites. This test validates the *runtime contract* of the same shape.

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/build_tracker.dart';

void main() {
  testWidgets(
    'FAB tap rebuilds only Text; sibling Icon rebuild count stays at zero',
    (tester) async {
      final textCounter = BuildCounter();
      final iconCounter = BuildCounter();

      await tester.pumpWidget(
        MaterialApp(
          home: _TrackedCounterPage(
            textCounter: textCounter,
            iconCounter: iconCounter,
          ),
        ),
      );

      expect(textCounter.count, 1, reason: 'Text built once on initial mount');
      expect(iconCounter.count, 1, reason: 'Icon built once on initial mount');
      expect(find.text('Counter is 0'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(textCounter.count, 2, reason: 'Text rebuilt once after FAB tap');
      expect(
        iconCounter.count,
        1,
        reason: 'Icon must NOT rebuild — it is outside the SignalBuilder',
      );
      expect(find.text('Counter is 1'), findsOneWidget);
    },
  );
}

class _TrackedCounterPage extends StatefulWidget {
  const _TrackedCounterPage({
    required this.textCounter,
    required this.iconCounter,
  });

  final BuildCounter textCounter;
  final BuildCounter iconCounter;

  @override
  State<_TrackedCounterPage> createState() => _TrackedCounterPageState();
}

class _TrackedCounterPageState extends State<_TrackedCounterPage> {
  final counter = Signal<int>(0, name: 'counter');

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
            return BuildTracker(
              counter: widget.textCounter,
              child: Text('Counter is ${counter.value}'),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: BuildTracker(
          counter: widget.iconCounter,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
