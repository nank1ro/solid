// GAP 1 of the post-#106 residual gap survey: a `StatelessWidget` pure
// consumer — constructor-injected `final AuthRepository authRepository;`,
// no `@Solid*` annotation of its own — reads `authRepository.session`
// inside `build()`. Before the fix, `cross_file_consumer_rewriter.dart`
// only visited `ClassKind.plainClass` declarations; a widget class needed
// BOTH the `.value` lowering AND a `SignalBuilder` wrap around the tracked
// subtree to actually rebuild when `session` changes, so it was skipped
// verbatim rather than emitted half-reactive.
//
// The wrap reuses the existing `rewriteBuildMethod` machinery verbatim — no
// widget-class Stateless→Stateful lift is needed here: unlike
// `@SolidEnvironment` (which needs `context.read<T>()` and therefore a
// `State<X>`), a constructor-injected field needs no `BuildContext` at all,
// so the class stays a `StatelessWidget`.
import 'package:flutter/widgets.dart';

import 'auth_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen(this.authRepository, {super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Text(authRepository.session ?? 'anonymous');
  }
}
