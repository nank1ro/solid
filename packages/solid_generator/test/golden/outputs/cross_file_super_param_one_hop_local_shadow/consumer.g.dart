// PURE CONSUMER regression fixture (issue #108 fix review, finding 1):
// this file declares its OWN plain `class Foo` (zero `@SolidState`
// members) — held by `Holder` through ordinary constructor injection — and
// ALSO extends `Base` (declared in `base.dart`) through a bare `super.x`
// constructor parameter. `Base` itself is reached directly (main walk), but
// `Base`'s OWN field `thing` is typed with a DIFFERENT, `@SolidState`-
// bearing `Foo` declared in `foreign_foo.dart` — a file this file never
// imports at all; only `base.dart` does. Locating that declaration needs
// the fix review finding 1 one-hop extension.
//
// Before the fix: the one-hop walk registered the FOREIGN `Foo`'s reactive
// `label` field into `classRegistry['Foo']` before this file's own local
// `Foo` had a chance to shadow it, so `Holder.f.label` — a read against the
// LOCAL plain class — was wrongly rewritten to `f.label.value` (BLOCKER:
// non-compiling output, `.value` on a plain `String?` field).
//
// After the fix: the one-hop registration is gated against THIS file's own
// declared type names, same discipline as the main walk (issue #104) — so
// `classRegistry` never gains a `'Foo'` entry at all once this file
// declares its own local `Foo`, name-based collision with no library
// qualification being the design's documented residual risk (SPEC §4.9).
// `f.label` correctly stays un-rewritten (the BLOCKER is closed); `Bar`'s
// `thing.label` — genuinely reactive through the foreign `Foo` — ALSO stays
// un-rewritten as the accepted, conservative cost of a safe fix: this file
// already has a local `Foo` claim on that simple name, so the registry
// cannot safely attribute `label` to `thing` either, exactly the same
// trade-off `cross_file_local_shadowing_decoy` (issue #104) already
// accepts. Favoring "no wrong rewrite" over "no missed rewrite" is
// consistent with every other ambiguity-handling rule in this file.
import 'base.dart';

class Foo {
  String? label;
}

class Holder {
  Holder(this.f);

  final Foo f;

  String? readLabel() => f.label;
}

class Bar extends Base {
  Bar(super.thing);

  String? readThing() => thing.label;
}
