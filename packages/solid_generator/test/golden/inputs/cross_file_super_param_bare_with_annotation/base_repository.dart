// Plain, unannotated base class that owns the `authRepository` field.
// `customers_repository.dart` never redeclares this field — it only
// forwards to it through a BARE super-initializer parameter (no type
// written) — so any read of `authRepository` in the subclass is an
// INHERITED-member read. See GAP 3 of the post-#106 residual gap survey.
import 'auth_repository.dart';

class BaseRepository {
  BaseRepository(this.authRepository);

  final AuthRepository authRepository;
}
