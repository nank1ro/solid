// M3-04 — proves SPEC §7.4 (siblings do not share wrappers) at runtime:
// mutating signal A rebuilds only widget A; widget B's rebuild count stays
// at zero. Validates that M1-05's minimum-subtree wrap rule (SPEC §7.2)
// produces sibling isolation.
//
// Mutation goes through a `GlobalKey<State>` (same shape `counter_dispose_test`
// uses) so the assertion isolates placement behaviour from tap/gesture wiring
// — if SPEC §7.4 is ever violated, the failure points straight at the wrap
// rule rather than at button plumbing.

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/build_tracker.dart';

void main() {
  testWidgets('siblings reading different signals rebuild independently', (
    tester,
  ) async {
    final counterA = BuildCounter();
    final counterB = BuildCounter();
    final pageKey = GlobalKey<_TrackedSiblingPageState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _TrackedSiblingPage(
          key: pageKey,
          counterA: counterA,
          counterB: counterB,
        ),
      ),
    );

    expect(counterA.count, 1, reason: 'A built once on initial mount');
    expect(counterB.count, 1, reason: 'B built once on initial mount');
    expect(find.text('A is 0'), findsOneWidget);
    expect(find.text('B is 0'), findsOneWidget);

    pageKey.currentState!.signalA.value++;
    await tester.pump();

    expect(counterA.count, 2, reason: 'A rebuilt after signalA mutation');
    expect(
      counterB.count,
      1,
      reason: 'B must NOT rebuild — its SignalBuilder reads only signalB',
    );
    expect(find.text('A is 1'), findsOneWidget);
    expect(find.text('B is 0'), findsOneWidget);

    pageKey.currentState!.signalB.value++;
    await tester.pump();

    expect(counterA.count, 2, reason: 'A unchanged after signalB mutation');
    expect(counterB.count, 2, reason: 'B rebuilt after signalB mutation');
    expect(find.text('A is 1'), findsOneWidget);
    expect(find.text('B is 1'), findsOneWidget);
  });
}

class _TrackedSiblingPage extends StatefulWidget {
  const _TrackedSiblingPage({
    required this.counterA,
    required this.counterB,
    super.key,
  });

  final BuildCounter counterA;
  final BuildCounter counterB;

  @override
  State<_TrackedSiblingPage> createState() => _TrackedSiblingPageState();
}

class _TrackedSiblingPageState extends State<_TrackedSiblingPage> {
  final signalA = Signal<int>(0, name: 'signalA');
  final signalB = Signal<int>(0, name: 'signalB');

  @override
  void dispose() {
    signalB.dispose();
    signalA.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SignalBuilder(
            builder: (context, child) {
              return BuildTracker(
                counter: widget.counterA,
                child: Text('A is ${signalA.value}'),
              );
            },
          ),
          SignalBuilder(
            builder: (context, child) {
              return BuildTracker(
                counter: widget.counterB,
                child: Text('B is ${signalB.value}'),
              );
            },
          ),
        ],
      ),
    );
  }
}
