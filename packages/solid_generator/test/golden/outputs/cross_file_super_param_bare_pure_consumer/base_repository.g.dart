// Plain, unannotated base class owning the `authRepository` field through
// the `this.x` field-formal shape — the primary real-world DI pattern issue
// #108 targets: the field itself carries no type annotation at the
// parameter position (`this.authRepository`), only on the field
// declaration below it. Also declares a NAMED constructor forwarding the
// same field, exercising the named-super-constructor matching branch
// (`super.named(...)` in `customers_repository.dart`), and a second named
// constructor whose forwarded param is itself NAMED (`{required
// this.authRepository}`) — issue #108 fix review addendum finding 4's
// NAMED bare-super-formal branch, matched against
// `PartnersRepository({required super.authRepository})` in
// `customers_repository.dart`.
import 'auth_repository.dart';

class BaseRepository {
  BaseRepository(this.authRepository);

  BaseRepository.named(this.authRepository);

  BaseRepository.namedParam({required this.authRepository});

  final AuthRepository authRepository;
}
