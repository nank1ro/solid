// SPEC §10 example uses `print` as the user-dispose-body sample statement.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  @SolidState()
  int value = 0;

  final StreamSubscription<void> _ticker = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  @override
  void dispose() {
    unawaited(_ticker.cancel());
    print('counter cleanup');
  }
}
