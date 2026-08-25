// Unrelated cross-file class that happens to share the simple name
// `Address` with `main.dart`'s own plain class. `@SolidState`-annotated so,
// absent the local-declaration-shadowing fix, the cross-file import walk in
// `builder.dart::_populateCrossFileTypes` wrongly attributes this class's
// reactive `line1` field to `main.dart`'s LOCAL plain `Address` class
// (BLOCKER regression, issue #104 fix review, finding 1).
import 'package:solid_annotations/solid_annotations.dart';

class Address {
  @SolidState()
  String? line1;
}
