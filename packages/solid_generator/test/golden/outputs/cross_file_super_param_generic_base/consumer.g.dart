// PURE CONSUMER whose ONLY link to `AuthRepository` is a BARE `super.repo`
// constructor parameter forwarding into a GENERIC superclass (issue #108
// fix review addendum finding 2): `Base<T>`'s own field is typed with ITS
// OWN type parameter `T`, not a concrete class name (`Base(this.repo);
// final T repo;`). Naively seeding the matched field's declared type would
// seed the literal string `"T"` — a syntactically valid `NamedType`, so it
// slips past the `matchedType is! NamedType` ambiguity gate — instead of
// the REAL concrete type, `AuthRepository`; no class is ever named `T`, so
// the wanted-type set fills with a name that matches nothing and
// `repo.session` stays silently un-lowered.
//
// The fix maps `T` BY INDEX to `C`'s own `extends Base<AuthRepository>`
// type argument instead of seeding the placeholder name verbatim.
import 'auth_repository.dart';
import 'base_repository.dart';

class C extends Base<AuthRepository> {
  C(super.repo);

  bool hasSession() => repo.session.value != null;
}
