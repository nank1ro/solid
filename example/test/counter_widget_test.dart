// M1-10 — Widget test: a FAB tap rebuilds only the `Text` widget; the sibling
// `Icon` (outside the `SignalBuilder` subtree) does not rebuild.
//
// SPEC §7 (SignalBuilder placement): the generator wraps the *smallest*
// subtree containing each tracked read. For the canonical M1-05 counter, that
// subtree is `Text('Counter is ${counter.value}')` only. The `Icon` lives on
// `floatingActionButton`, which is outside the `SignalBuilder` and therefore
// must not rebuild when `counter.value` changes.
//
// This test mounts a private `_TrackedCounterPage` whose structure mirrors the
// M1-05 generated output (see `example/lib/counter.dart` and
// `packages/solid_generator/test/golden/outputs/m1_05_counter_stateless_full.g.dart`)
// except that the `Text` and `Icon` leaves are wrapped in `BuildTracker`
// widgets. The pattern under test is what M1-05 produces; the byte-for-byte
// correspondence is already validated by the golden + idempotency suites.

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

      // After mount: each tracker has been built exactly once.
      expect(textCounter.count, 1, reason: 'Text built once on initial mount');
      expect(iconCounter.count, 1, reason: 'Icon built once on initial mount');
      expect(find.text('Counter is 0'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // After FAB tap: the SignalBuilder's subtree (Text) rebuilt once; the
      // Icon, outside SignalBuilder, did NOT rebuild. iconCounter.count must
      // still equal 1 — zero rebuilds beyond the initial mount.
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

/// Test-only mirror of the M1-05 generated `_CounterPageState` with
/// `BuildTracker` wrappers around the `Text` and `Icon` leaves. See the file
/// header for why this is a hand-written mirror rather than the actual
/// generated `CounterPage`.
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
