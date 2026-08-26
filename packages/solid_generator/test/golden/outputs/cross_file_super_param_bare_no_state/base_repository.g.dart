// Plain, unannotated base class owning the `plain` field through the
// `this.x` field-formal shape — same DI pattern as
// `cross_file_super_param_bare_pure_consumer`, but pointing at a
// non-`@SolidState` type (see `plain_repository.dart`).
import 'plain_repository.dart';

class BaseRepository {
  BaseRepository(this.plain);

  final PlainRepository plain;
}
