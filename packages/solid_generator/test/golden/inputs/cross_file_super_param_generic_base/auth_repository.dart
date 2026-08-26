// Cross-file `@SolidState` host for the generic-superclass regression
// (issue #108 fix review addendum finding 2).
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
