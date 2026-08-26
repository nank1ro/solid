// Cross-file `@SolidState` host for the combinator-blind import-repair
// regression below (see `profile_screen.dart` in this fixture directory).
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
