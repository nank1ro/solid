// Plain, unannotated base class that owns the `authRepository` field.
// `customers_repository.dart` never redeclares this field — it only
// forwards to it through an explicitly-typed super-initializer parameter —
// so any read of `authRepository` in the subclass is an INHERITED-member
// read. See issue #104 fix review, finding 3.
import 'auth_repository.dart';

class BaseRepository {
  BaseRepository(this.authRepository);

  final AuthRepository authRepository;
}
