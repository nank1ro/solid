// Cross-file `@SolidState` controller — see the sibling
// `cross_file_dispose_unannotated_main` fixture's `controller.dart` for the
// full rationale. This copy exists so each multi-file golden fixture stays
// self-contained.

import 'package:solid_annotations/solid_annotations.dart';

class CitiesController {
  @SolidState()
  int count = 0;
}
