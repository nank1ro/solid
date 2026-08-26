// Pass-ordering regression: a WIDGET pure consumer (`WelcomeBanner`, GAP 1
// of the post-#106 residual gap survey) and a static-holder-mediated PLAIN
// pure consumer (`RouterGuard`, GAP 2 of the same survey) in the SAME FILE.
//
// Before the fix, `builder.dart`'s no-annotation branch ran
// `lowerPureConsumerWidgetReads` first against the pristine source, then fed
// its OUTPUT into `lowerPureConsumerCrossFileReads` — but only passed that
// second call the still-resolved `unit` when the first call had made NO
// edit at all (`unit: identical(current, source) ? unit : null`). Because
// `WelcomeBanner.build()` DOES get edited (it needs both `.value` lowering
// and a `SignalBuilder` wrap), the plain-class pass was forced onto a fresh,
// UNRESOLVED re-parse of the widget-edited text.
//
// `RouterGuard.resolve()`'s `Holder.instance.session` read is a TIER-1-ONLY
// shape (see `cross_file_static_holder_read` for the isolated case): only
// `Expression.staticType` on the `PrefixedIdentifier` target
// (`Holder.instance`) resolves the receiver to `AuthRepository`, and that
// tier is unavailable on an unresolved unit. So whenever this file ALSO
// contained a widget pure consumer, the guard's read silently stayed
// un-lowered — reproducing the original #106 authentication-bypass shape
// (`dart fix`'s `unnecessary_null_comparison`/`dead_code` passes can
// collapse the null check once the `Signal` object looks always-non-null).
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'auth_repository.dart';

class Holder {
  static final AuthRepository instance = AuthRepository();
}

class RouterGuard {
  String resolve() {
    if (Holder.instance.session.value == null) {
      return '/login';
    } else {
      return '/home';
    }
  }
}

class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner(this.authRepository, {super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(authRepository.session.value ?? 'anonymous');
      },
    );
  }
}
