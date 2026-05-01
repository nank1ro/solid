// The `final`-without-`late`, uninitialized field IS the rejection target —
// the M6-07 validator flags it as `'final field'` (the `isFinal && !isLate`
// check fires before the initializer-presence check). `late final Counter c;`
// is the *valid* shape per SPEC §3.6; the realistic user mistake is
// forgetting `late`, with no manual constructor call (`@SolidEnvironment` is
// the initialization). Suppress the corresponding analyzer error so
// `dart analyze` stays clean on this fixture.
// ignore_for_file: final_not_initialized

import 'package:solid_annotations/solid_annotations.dart';

class Counter {}

class Foo {
  @SolidEnvironment()
  final Counter c;
}
