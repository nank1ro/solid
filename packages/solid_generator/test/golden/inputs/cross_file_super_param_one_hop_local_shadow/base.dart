// `Bar`'s superclass, reached one hop away from `consumer.dart` (which
// imports only this file, never `foreign_foo.dart` directly). Owns `thing`
// through the ordinary `this.x` field-formal shape, typed with THIS file's
// own imported `Foo` — the FOREIGN, `@SolidState`-bearing one.
import 'foreign_foo.dart';

class Base {
  Base(this.thing);

  final Foo thing;
}
