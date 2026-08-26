// Cross-file `@SolidState` host for the pass-ordering regression below (see
// `app.dart` in this fixture directory for the actual reproduction).
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
