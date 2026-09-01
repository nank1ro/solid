// Real (resolved) fixture for `resolved_signal_detection_test.dart`.
//
// Lives on disk, not as an inline string, because both scenarios below need
// a GENUINE `package:flutter_solidart` resolution — `resolveFile` only gets
// that from a path inside the pub workspace's shared `package_config.json`.
// `solid_generator`'s own `pubspec.yaml` does not depend on
// `flutter_solidart`, but the workspace (`resolution: workspace` at the repo
// root) resolves one shared `package_config.json` covering every member —
// `integration_tests` depends on `flutter_solidart` for real, so a file
// physically under this package's own `test/` directory resolves it too.
//
//  * `ResolvedEnvironmentHost.counter` — a `@SolidEnvironment` field typed
//    `Signal<int>` must be rejected. `Signal`'s resolved supertype chain
//    reaches `SignalBase`, whose DECLARING library is `package:solidart`
//    (`flutter_solidart` only re-exports it) — the case a check anchored to
//    `packageName: 'flutter_solidart'` can never match in a real (resolved)
//    build, only in this package's own unresolved test sandbox where the
//    lexeme fallback papers over it.
//  * `readAlias` — `final alias = bag.sig; return alias.value;` reads a
//    foreign signal through a LOCAL ALIAS. The resolved `staticType` of
//    `alias` is `Signal<int>` regardless of the local's own name, so this
//    read must be tracked even though `alias` is itself declared in the
//    enclosing scope (and would trip a shadow guard that ran before
//    consulting the resolved type).
//  * `readOptOut` — `bag.sig.untracked.value` (the Section 6.4 opt-out
//    spelling) must NOT be tracked. `solid_annotations`'s
//    `UntrackedExtension<T> on T` is an identity getter generic over every
//    type, so `bag.sig.untracked`'s resolved `staticType` is still
//    `Signal<int>` — only the trailing `.untracked` property name says "do
//    not subscribe". This receiver shape (a chain through a generic
//    extension getter) is also NOT reachable via the golden fixture's
//    unresolved-AST fallback tier, unlike `readAlias`.
//
// `flutter_solidart` is deliberately not a declared dependency of this
// package (see above) — that's the whole point of the fixture, so the lint
// is expected here.
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ResolvedEnvironmentHost {
  @SolidEnvironment()
  late Signal<int> counter;
}

class SignalBag {
  final Signal<int> sig = Signal(0);
}

int readAlias(SignalBag bag) {
  final alias = bag.sig;
  return alias.value;
}

int readOptOut(SignalBag bag) {
  return bag.sig.untracked.value;
}
