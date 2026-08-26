// PURE CONSUMER at the top of a TWO-LEVEL bare-`super.x` chain (issue #108
// fix review addendum finding B): `LeafRepository`'s bare parameter
// forwards to `MidRepository`'s OWN bare parameter (not a typed field or a
// `this.x` field-formal — `MidRepository` merely relays it one level
// further), which in turn forwards to `BaseRepository`'s `this.x`
// field-formal, which finally names `AuthRepository` on its field
// declaration. Locating `AuthRepository`'s own class declaration from
// there needs the fix review finding 1 one-hop extension too — this file
// imports only `mid_repository.dart`; `mid_repository.dart` imports only
// `base_repository.dart`; `AuthRepository` is declared in
// `auth_repository.dart`, which only `base_repository.dart` imports. No
// `@Solid*` annotation and no provider hint anywhere in this file, so it
// takes the no-annotation fast path's syntactic probe.
import 'mid_repository.dart';

class LeafRepository extends MidRepository {
  LeafRepository(super.authRepository);

  bool hasSession() => authRepository.session.value != null;
}
