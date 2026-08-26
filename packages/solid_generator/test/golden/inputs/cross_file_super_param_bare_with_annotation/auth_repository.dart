// Cross-file `@SolidState` host for the bare-`super.` regression (GAP 3 of
// the post-#106 residual gap survey). See `customers_repository.dart` for
// the shape under test.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
