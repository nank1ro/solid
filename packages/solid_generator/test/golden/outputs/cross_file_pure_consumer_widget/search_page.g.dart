// GAP 1 of the post-#106 residual gap survey — the `State<X>` shape. The
// `State` subclass copies the constructor-injected `AuthRepository` off its
// `widget` in `initState()` into its OWN field and carries no `@Solid*`
// annotation of its own, so `_SearchPageState.build()` needs the same
// `.value` + `SignalBuilder` treatment as the `StatelessWidget` shape in
// `profile_screen.dart`.
//
// This deliberately reads its OWN field (`authRepository.session`) rather
// than the usual Flutter `widget.<field>` indirection directly inside
// `build()`. The `widget.<field>.<reactiveField>` shape is a THREE-level
// chain (`PropertyAccess` whose target is a `PrefixedIdentifier`, not a bare
// identifier or a `this.<field>` `PropertyAccess`) that only
// `value_rewriter.dart`'s tier-1 `Expression.staticType` resolution can
// recognize — this test sandbox has no `flutter` SDK dependency, so
// `package:flutter/widgets.dart` never actually resolves and every file
// importing it falls back to the unresolved parsed AST (see
// `builder.dart::_resolveUnit`'s doc comment). Proving the `widget.<field>`
// shape end-to-end needs either a real resolver or a new AST tier for a
// `PrefixedIdentifier`-target `PropertyAccess` chain — out of scope for
// this fixture; this file instead pins the shape that already resolves via
// the existing tier-3 AST fallback regardless of resolution, which is
// exactly parallel to `cross_file_pure_consumer`'s plain-class coverage.
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'auth_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage(this.authRepository, {super.key});

  final AuthRepository authRepository;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final AuthRepository authRepository;

  @override
  void initState() {
    super.initState();
    authRepository = widget.authRepository;
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(authRepository.session.value ?? 'anonymous');
      },
    );
  }
}
