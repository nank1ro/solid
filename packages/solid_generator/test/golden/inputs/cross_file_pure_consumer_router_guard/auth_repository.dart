// Cross-file `@SolidState` host for the router-guard variant of the PURE
// CONSUMER regression (issue #106) — see `cross_file_pure_consumer/
// auth_repository.dart` for the base shape.

import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
