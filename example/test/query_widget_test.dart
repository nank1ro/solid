// M5-07 — fences SPEC §3.5 (Refresh) and §10 (Resource disposal) at
// runtime. `_QueryCounterPage` mirrors the M5-06 lowered shape but swaps
// the constant fetcher `() async => 0` for a closure over the top-level
// `_testCounter` so invocation count is observable.
//
// Resource accounting: `Resource` is lazy by default. The first
// `SignalBuilder` build calls `fetchCount()` (`Resource<T>.call() => state`),
// triggering the initial fetch. The fetcher returns `_testCounter++`
// (post-increment), so the first ready value is `0` and `_testCounter`
// becomes `1`. Each FAB tap calls `fetchCount.refresh()`, re-running the
// fetcher once. After three taps the ready value is `3` and `_testCounter`
// is `4` — three produced by tap, one by the lazy mount-time fetch.
//
// The dispose test parallels M1-11 / M4-07: Navigator push/pop +
// `fetchCount.onDispose` hook. `Resource<T>` extends
// `Signal<ResourceState<T>>`, so it inherits `SignalBase.onDispose`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';

var _testCounter = 0;

void main() {
  setUp(() => _testCounter = 0);

  testWidgets('FAB tap fires fetcher on each refresh', (tester) async {
    final pageKey = GlobalKey<_QueryCounterPageState>();

    await tester.pumpWidget(
      MaterialApp(home: _QueryCounterPage(key: pageKey)),
    );
    await tester.pumpAndSettle();

    expect(
      _testCounter,
      1,
      reason: 'Lazy Resource fetched once on first SignalBuilder build',
    );
    expect(
      find.text('0'),
      findsOneWidget,
      reason: 'Post-increment yields the pre-increment value 0 in ready state',
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
        find.text('${i + 1}'),
        findsOneWidget,
        reason: '.when(ready) re-emits with new value after refresh #${i + 1}',
      );
    }

    expect(
      _testCounter,
      4,
      reason: '1 lazy mount-time fetch + 3 refresh fetches',
    );
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Navigator pop disposes the Resource exactly once', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final pageKey = GlobalKey<_QueryCounterPageState>();
    var disposeCount = 0;

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => _QueryCounterPage(key: pageKey),
        ),
      ),
    );
    await tester.pumpAndSettle();

    pageKey.currentState!.fetchCount.onDispose(() => disposeCount++);

    expect(
      disposeCount,
      0,
      reason: 'Resource alive while the page is mounted',
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(
      disposeCount,
      1,
      reason:
          'Navigator pop must run State.dispose() exactly once, disposing '
          'the Resource whose onDispose hook is observed here',
    );
  });
}

class _QueryCounterPage extends StatefulWidget {
  const _QueryCounterPage({super.key});

  @override
  State<_QueryCounterPage> createState() => _QueryCounterPageState();
}

class _QueryCounterPageState extends State<_QueryCounterPage> {
  late final fetchCount = Resource<int>(
    () async => _testCounter++,
    name: 'fetchCount',
  );

  @override
  void dispose() {
    fetchCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return fetchCount().when(
              ready: (v) => Text('$v'),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('error: $e'),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(fetchCount.refresh()),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
