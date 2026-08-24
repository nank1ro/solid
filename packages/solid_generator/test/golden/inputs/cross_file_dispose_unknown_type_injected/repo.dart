// Plain, dispose-less, NOT `@Solid*`-annotated cross-file class — the
// "unknown" case (tier 4 of the auto-dispose decision rule). On the main
// annotated path (see `main.dart`), `addProviderDisposeAtCallSites` never
// gets a resolver, so it cannot prove this type is dispose-less the way it
// can for a plain SAME-FILE class (`_hasDisposeInSameUnit` only looks at the
// file being scanned). `AuthRepository` is real and resolvable everywhere
// else in the toolchain — it just isn't provably plain to THIS checker.

class AuthRepository {
  String? session;
}
