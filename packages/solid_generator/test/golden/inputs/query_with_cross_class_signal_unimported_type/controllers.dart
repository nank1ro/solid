// Cross-file `@SolidState` host. The `unit` field's type `Unit` is declared
// in a sibling file (`types.dart`) which this file imports.

import 'package:solid_annotations/solid_annotations.dart';

import 'types.dart';

class Settings {
  @SolidState()
  Unit unit = Unit.a;
}
