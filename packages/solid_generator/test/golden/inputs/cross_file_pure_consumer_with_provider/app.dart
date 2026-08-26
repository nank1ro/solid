// Combo regression: this ONE file both (a) creates a cross-file
// `@SolidState`-bearing `AuthRepository` at a `Provider<AuthRepository>(...)`
// call site with `dispose:` omitted — so `addProviderDisposeAtCallSites`
// EDITS the text — and (b) reads that same cross-file class's reactive field
// through a for-in LOOP-VARIABLE null-guard on an annotation-free plain
// class (`RepoGuard`) — the #106 pure-consumer shape.
//
// Before the fix, the builder ran the dispose pass FIRST. Because that pass
// edited the text, `lowerPureConsumerCrossFileReads` received `unit: null`
// (offsets shifted out from under the resolved unit) and fell back to a
// freshly re-parsed, UNRESOLVED `CompilationUnit`. `r` is a for-in loop
// variable, not a parameter or field — the ONLY tier of
// `value_rewriter.dart`'s receiver resolution that can type it is tier 1
// (`Expression.staticType`), which requires a resolved unit. So `r.session`
// stayed un-lowered — a bare `String?` field read — and `dart fix`'s
// `dead_code`/`unnecessary_null_comparison` passes could collapse the null
// guard: the #106 auth-bypass class, reintroduced through this second path.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'auth_repository.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Provider<AuthRepository>(
      create: (_) => AuthRepository(),
      child: child,
    );
  }
}

class RepoGuard {
  RepoGuard(this.repos);

  final List<AuthRepository> repos;

  String check() {
    for (final r in repos) {
      if (r.session == null) {
        return 'missing';
      } else {
        return 'present';
      }
    }
    return 'empty';
  }
}
