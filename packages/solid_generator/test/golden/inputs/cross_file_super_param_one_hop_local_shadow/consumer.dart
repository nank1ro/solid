// PURE CONSUMER regression fixture (issue #108 fix review, finding 1;
// promoted to the PRIMARY fixture for issue #110): this file declares its
// OWN plain `class Foo` (zero `@SolidState` members) — held by `Holder`
// through ordinary constructor injection — and ALSO extends `Base` (declared
// in `base.dart`) through a bare `super.x` constructor parameter. `Base`
// itself is reached directly (main walk), but `Base`'s OWN field `thing` is
// typed with a DIFFERENT, `@SolidState`-bearing `Foo` declared in
// `foreign_foo.dart` — a file this file never imports at all; only
// `base.dart` does. Locating that declaration needs the fix review finding 1
// one-hop extension.
//
// Pre-#108-fix-review: the one-hop walk registered the FOREIGN `Foo`'s
// reactive `label` field into `classRegistry['Foo']` before this file's own
// local `Foo` had a chance to shadow it, so `Holder.f.label` — a read
// against the LOCAL plain class — was wrongly rewritten to `f.label.value`
// (BLOCKER: non-compiling output, `.value` on a plain `String?` field).
//
// Pre-#110 (the fix that closed the BLOCKER above): the one-hop
// registration was gated against this file's own declared type names, so
// `classRegistry` never gained a `'Foo'` entry AT ALL once this file
// declared its own local `Foo` — `f.label` correctly stayed un-rewritten,
// but `Bar`'s `thing.label` — genuinely reactive through the foreign `Foo`
// — ALSO stayed un-rewritten, as the accepted conservative cost of a safe
// fix: the registry could not tell `f`'s `Foo` (this file) from `thing`'s
// `Foo` (foreign_foo.dart) by simple name alone.
//
// After issue #110: the registry stops dropping the foreign entry and
// instead records it QUALIFIED by origin library
// (`builder.dart::_registerWantedClassesFrom` → `classRegistryOrigins`).
// Both `f` and `thing` resolve through the RESOLVED path here (this is the
// no-annotation pure-consumer branch, which still runs against a
// `buildStep.resolver`-backed `CompilationUnit` — see `builder.dart::
// _resolveUnit`), so `value_rewriter.dart`'s tier 1 sees each receiver's
// real `staticType`: `f`'s element library is THIS file (`consumer.dart`
// itself), `thing`'s element library is `foreign_foo.dart`. Comparing each
// against `Foo`'s recorded origin (`foreign_foo.dart` only) now
// DISAMBIGUATES precisely: `f.label` still never rewrites (`f`'s library
// doesn't match), and `thing.label` — previously blocked — now correctly
// lowers to `thing.label.value`. See `_ValueRewriteVisitor.
// _fieldsForCrossClassName` for the full safety invariant this depends on.
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
