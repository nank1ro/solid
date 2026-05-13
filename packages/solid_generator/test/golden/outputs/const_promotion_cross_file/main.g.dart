// User's bug-shape: a `main.dart` that imports `flutter_solidart` but declares
// no `@Solid*` annotation of its own. The file used to pass through verbatim
// (no Solid annotation -> fast-path bypass), so `runApp(MaterialApp(home:
// CounterPage()))` never received `const` even though both ctors are const.
// After §4.10 the file is visited, resolved analysis recognizes `MaterialApp`
// as const-eligible, and the outer call site is promoted to `const
// MaterialApp(home: CounterPage())`. `CounterPage` is contributed by the
// per-file declaration-emitted name set from `counter.dart`'s lowering.

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'counter.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(MaterialApp(home: const CounterPage()));
}
