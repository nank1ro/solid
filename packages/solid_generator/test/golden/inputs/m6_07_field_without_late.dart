// The non-nullable, non-`late`, uninitialized field IS the rejection target —
// the M6-07 validator flags it as `'non-late field'`. Suppress the
// corresponding analyzer error so `dart analyze` stays clean on this fixture.
// ignore_for_file: not_initialized_non_nullable_instance_field

import 'package:solid_annotations/solid_annotations.dart';

class Counter {}

class Foo {
  @SolidEnvironment()
  Counter c;
}
