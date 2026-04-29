// M4-07 — fences SPEC §4.7 (`@SolidEffect` on method → `Effect`) at runtime.
// `_EffectCounterPage` mirrors the M4-01 lowered shape, including the
// synthesized `initState()` that materializes the `late final` Effect field
// at mount time. Without that read, the Effect's autorun never fires during
// the widget's mounted lifetime — see SPEC §4.7 last bullet.
//
// Effect history accounting: the autorun fires once at mount with
// `counter.value == 0`, recording `[0]`. Each FAB tap mutates `counter`,
// re-firing the Effect with the new value. After three taps the recorded
// history is `[0, 1, 2, 3]` — four entries, three produced by tap.
//
// The dispose test parallels M1-11; reverse-declaration disposal order is
// golden-asserted in M4-02, not retested here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FAB tap fires Effect body on each counter change', (
    tester,
  ) async {
    final pageKey = GlobalKey<_EffectCounterPageState>();

    await tester.pumpWidget(
      MaterialApp(home: _EffectCounterPage(key: pageKey)),
    );

    expect(
      pageKey.currentState!.history.value,
      <int>[0],
      reason:
          'Effect autorun fires once at mount when initState materializes '
          'the late final, recording the initial counter value',
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
    }

    expect(
      pageKey.currentState!.history.value,
      <int>[0, 1, 2, 3],
      reason: 'one re-run per tap plus the mount-time entry',
    );
  });

  testWidgets('Navigator pop disposes the counter signal exactly once', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final pageKey = GlobalKey<_EffectCounterPageState>();
    var disposeCount = 0;

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => _EffectCounterPage(key: pageKey),
        ),
      ),
    );
    await tester.pumpAndSettle();

    pageKey.currentState!.counter.onDispose(() => disposeCount++);

    expect(
      disposeCount,
      0,
      reason: 'Signal must be alive while the page is mounted',
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(
      disposeCount,
      1,
      reason:
          'Navigator pop must run the State `dispose()` body exactly once, '
          'disposing the Signal whose onDispose hook is observed here',
    );
  });
}

class _EffectCounterPage extends StatefulWidget {
  const _EffectCounterPage({super.key});

  @override
  State<_EffectCounterPage> createState() => _EffectCounterPageState();
}

class _EffectCounterPageState extends State<_EffectCounterPage> {
  final counter = Signal<int>(0, name: 'counter');
  final history = Signal<List<int>>(<int>[], name: 'history');
  // Reads `history.untrackedValue` (the M3-12 `.untracked` lowering, SPEC
  // §6.4) so the spread does not register `history` as a tracked dependency.
  // Otherwise the same Effect that writes `history.value` would re-run on
  // its own write — a self-dep loop. Only `counter.value` is tracked, so the
  // Effect re-runs exactly when the counter changes.
  late final recordHistory = Effect(() {
    history.value = [...history.untrackedValue, counter.value];
  }, name: 'recordHistory');

  @override
  void initState() {
    super.initState();
    recordHistory;
  }

  @override
  void dispose() {
    recordHistory.dispose();
    history.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) => Text('Counter is ${counter.value}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
