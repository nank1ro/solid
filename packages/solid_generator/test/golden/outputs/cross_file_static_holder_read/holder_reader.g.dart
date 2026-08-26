// Static-field-mediated DI / singleton-holder shape (GAP 2 of the post-#106
// residual gap survey): `Holder.instance` is the receiver, not a
// constructor-injected field. Before the fix, the DI-seeding loop in
// `builder.dart::_populateCrossFileTypes` had `if (member.isStatic)
// continue;` with no stated rationale (see git history for #104/#105), so
// `AuthRepository` never entered `wantedTypes` from `Holder.instance`'s
// declared type and `Holder.instance.session` reads stayed silently
// un-lowered.
//
// Receiver resolution needed NO new AST tier: `Holder.instance.session`
// parses as `PropertyAccess(target: PrefixedIdentifier(Holder, instance),
// propertyName: session)`, and the existing tier-1
// `Expression.staticType` resolution on the `PrefixedIdentifier` target
// already resolves to `AuthRepository` under a real resolved unit (verified
// empirically against `package:analyzer` directly) — once `AuthRepository`
// is seeded into the registry, `_maybeRewriteCrossClassPropertyAccess`
// already fires.
import 'auth_repository.dart';

class Holder {
  static final AuthRepository instance = AuthRepository();
}

class SessionReader {
  bool hasSession() {
    return Holder.instance.session.value != null;
  }

  int? sessionLength() => Holder.instance.session.value!.length;
}
