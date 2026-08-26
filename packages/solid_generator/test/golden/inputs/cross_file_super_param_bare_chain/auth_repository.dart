// Cross-file `@SolidState` host, reached only through a TWO-LEVEL chain of
// bare `super.x` constructor parameters (issue #108 fix review addendum
// finding B) — `leaf_repository.dart` forwards to `mid_repository.dart`,
// which itself forwards to `base_repository.dart`, which finally names
// this type on its own field declaration.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
