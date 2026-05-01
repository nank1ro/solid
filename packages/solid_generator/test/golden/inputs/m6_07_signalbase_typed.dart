// The `Signal<int>` type IS the rejection target — the M6-07 validator flags
// any field whose declared type's lexeme is in `signalBaseTypeNames`
// (`Signal` / `Computed` / `Effect` / `Resource`). The validator works on the
// unresolved AST, so no `flutter_solidart` import is needed; suppress the
// resulting `undefined_class` diagnostic so `dart analyze` stays clean on
// this fixture.
// ignore_for_file: undefined_class

import 'package:solid_annotations/solid_annotations.dart';

class Foo {
  @SolidEnvironment()
  late Signal<int> c;
}
