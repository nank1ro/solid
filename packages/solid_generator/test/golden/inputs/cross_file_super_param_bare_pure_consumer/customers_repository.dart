// PURE CONSUMER whose ONLY link to `AuthRepository` is a BARE `super.x`
// constructor parameter (issue #108) — no `@Solid*` annotation and no DI
// call site of any kind anywhere in this file, so it takes the
// no-annotation fast path's syntactic probe. Before the fix, a
// bare super-formal parameter carried no type text anywhere in the source
// for that unresolved probe to find, so the probe found nothing to seed
// and the file short-circuited to a verbatim copy — every read through
// `authRepository` stayed silently un-lowered (no `.value`).
//
// `CustomersRepository` covers the default (unnamed) super-constructor
// target, with a null-guard read and a `!`-chain read. `VendorsRepository`
// covers the NAMED super-constructor target (`super.named()`), matching
// the bare param against `BaseRepository.named`'s own field-formal
// parameter. `PartnersRepository` covers the NAMED bare-super-formal
// branch (`{required super.authRepository}`, issue #108 fix review
// addendum finding 4), matched against `BaseRepository.namedParam`'s own
// NAMED field-formal parameter.
//
// This file deliberately imports ONLY `base_repository.dart` — issue
// #108's fix review, finding 1: `AuthRepository` is never named in this
// file's text at all (the bare `super.authRepository` shorthand never
// spells it out), so the generator's cross-file registry walk can only
// find its declaration by following ONE MORE hop through
// `base_repository.dart`'s own import of `auth_repository.dart` — proving
// the fix actually closes issue #108's own primary example, a consumer
// that imports only the immediate superclass's file.
import 'base_repository.dart';

class CustomersRepository extends BaseRepository {
  CustomersRepository(super.authRepository);

  bool hasSession() {
    return authRepository.session != null;
  }

  int? sessionLength() => authRepository.session!.length;
}

class VendorsRepository extends BaseRepository {
  VendorsRepository(super.authRepository) : super.named();

  bool hasSession() => authRepository.session != null;
}

class PartnersRepository extends BaseRepository {
  PartnersRepository({required super.authRepository}) : super.namedParam();

  bool hasSession() => authRepository.session != null;
}
