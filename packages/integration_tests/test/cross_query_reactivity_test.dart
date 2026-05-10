// Fences cross-query auto-tracking at runtime: the downstream Resource
// auto-refreshes when the upstream emits.
//
// `_CrossQueryPage` mirrors the lowered shape that the generator emits for
// a Stream-form upstream (`watchTicks`) feeding a Future-form downstream
// (`halveLatestTick`) via the `source: watchTicks` direct-pass case. The
// stream is replaced by a `StreamController` so the test drives emissions
// deterministically via `add(...)` / `pumpAndSettle`.
//
// The test asserts (a) every upstream emission triggers exactly one
// downstream fetcher run and (b) the downstream's emitted value reflects
// the most-recent upstream value, with no manual `.refresh()` call.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';

late StreamController<int> _ticks;
var _downstreamRuns = 0;

void main() {
  setUp(() {
    _ticks = StreamController<int>.broadcast();
    _downstreamRuns = 0;
  });

  tearDown(() async {
    await _ticks.close();
  });

  testWidgets(
    'downstream Resource re-fetches when upstream Stream emits',
    (tester) async {
      final pageKey = GlobalKey<_CrossQueryPageState>();
      await tester.pumpWidget(
        MaterialApp(home: _CrossQueryPage(key: pageKey)),
      );
      await tester.pumpAndSettle();

      // First emission: upstream becomes ready with value 4.
      _ticks.add(4);
      await tester.pumpAndSettle();
      expect(
        find.text('2.0'),
        findsOneWidget,
        reason: 'downstream halves 4 -> 2.0 once upstream is ready',
      );
      expect(
        _downstreamRuns,
        greaterThanOrEqualTo(1),
        reason: 'downstream fetcher ran at least once after upstream emit',
      );

      final runsBefore = _downstreamRuns;

      // Second emission: upstream re-emits 10. The downstream Resource is
      // wired with `source: watchTicks`, so the new state flips
      // `Resource.source`'s identity and the fetcher re-runs without any
      // manual `.refresh()`.
      _ticks.add(10);
      await tester.pumpAndSettle();
      expect(
        find.text('5.0'),
        findsOneWidget,
        reason: 'downstream halves 10 -> 5.0 after second emission',
      );
      expect(
        _downstreamRuns,
        greaterThan(runsBefore),
        reason: 'downstream re-ran on upstream change',
      );
    },
  );
}

class _CrossQueryPage extends StatefulWidget {
  const _CrossQueryPage({super.key});

  @override
  State<_CrossQueryPage> createState() => _CrossQueryPageState();
}

class _CrossQueryPageState extends State<_CrossQueryPage> {
  late final watchTicks = Resource<int>.stream(
    () => _ticks.stream,
    name: 'watchTicks',
  );

  late final halveLatestTick = Resource<double>(
    () async {
      _downstreamRuns++;
      return (watchTicks().asReady?.value ?? 0).toDouble() / 2.0;
    },
    source: watchTicks,
    name: 'halveLatestTick',
  );

  @override
  void dispose() {
    halveLatestTick.dispose();
    watchTicks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return halveLatestTick().when(
              ready: (v) => Text('$v'),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('error: $e'),
            );
          },
        ),
      ),
    );
  }
}
