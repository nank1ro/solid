// Cross-file `@SolidState` host for the bare-`super.` PURE CONSUMER
// regression (issue #108). `customers_repository.dart` reaches this class
// ONLY through a bare `super.x` constructor parameter, with no `@Solid*`
// annotation and no provider hint anywhere in that file — the narrowest
// pure-consumer shape the #106/#107 machinery still missed, because
// detecting a pure consumer at all requires an UNRESOLVED syntactic
// pre-parse, and a bare `super.x` carries no type text for that pass to
// find without the fix.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
