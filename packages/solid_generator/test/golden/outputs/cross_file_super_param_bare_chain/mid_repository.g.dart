// Middle of the chain: forwards `authRepository` through its OWN bare
// `super.x` parameter rather than re-declaring a typed field or a `this.x`
// field-formal — the shape issue #108 fix review addendum finding B
// targets. Resolving `LeafRepository`'s bare parameter (in
// `leaf_repository.dart`) requires recursing PAST this class's own
// constructor to `BaseRepository`'s field-formal parameter.
import 'base_repository.dart';

class MidRepository extends BaseRepository {
  MidRepository(super.authRepository);
}
