// New fixture (issue #110): two DIFFERENT @SolidState classes, both named
// `Foo`, declared in DIFFERENT files (`foo_a.dart`, `foo_b.dart`), both
// reached from this PURE CONSUMER file via ordinary constructor injection —
// `foo_b.dart`'s `Foo` imported under a prefix so both bare and prefixed
// references coexist without a compile-time ambiguous-import error.
//
// `_populateCrossFileTypes`'s cross-file walk seeds a SINGLE 'Foo' entry
// into `wantedTypes` (the map is name-keyed, prefix-blind) from `Holder`'s
// two typed fields, then finds BOTH classes across this file's two imports
// — a genuine same-simple-name collision the registry could never safely
// resolve before issue #110 (SPEC §4.9's documented residual risk). Each
// match is recorded QUALIFIED by its own origin library into
// `classRegistryOrigins['Foo']`, and the name is flagged ambiguous in
// `classRegistryShadowedNames` — two distinct origins, no local shadow
// needed to trigger it this time.
//
// At rewrite time, `a`'s resolved `staticType` points at `foo_a.dart`'s
// `Foo`; `b`'s points at `foo_b.dart`'s `Foo` (the `foo_b.` prefix is a
// purely syntactic import-scoping device, invisible to the resolved
// element's OWN library URI). Each receiver's tier-1 URI matches ONLY its
// own class's recorded origin, so each read lowers against its own class's
// fields — the ultimate proof this is genuine per-origin disambiguation,
// not a lucky single-candidate default: `a.label` -> `a.label.value`
// (foo_a.dart's field), `b.count` -> `b.count.value` (foo_b.dart's field) —
// never the other way around.
import 'foo_a.dart';
import 'foo_b.dart' as foo_b;

class Holder {
  Holder(this.a, this.b);

  final Foo a;
  final foo_b.Foo b;

  String? readA() => a.label.value;

  int readB() => b.count.value;
}
