// The OTHER `Foo` — same simple name as `foo_a.dart`'s, an unrelated class
// with an unrelated reactive field. See `main.dart`.
import 'package:solid_annotations/solid_annotations.dart';

class Foo {
  @SolidState()
  int count = 0;
}
