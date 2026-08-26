// Cross-file `@SolidState` host for the combo regression below — see
// `app.dart` in this fixture directory for the shape that reproduces the
// bug.

import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
