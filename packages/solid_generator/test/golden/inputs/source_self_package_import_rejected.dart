// A source-side `package:<self>/...` import is rejected — source must import
// other source files via relative paths, not via the lib/-resolving package:
// URI. The `package:solid_annotations/...` import below stays allowed
// (different package); the `package:a/...` line is the violation, matching
// the test builder's default package name.

import 'package:solid_annotations/solid_annotations.dart';

// `package:a/sibling.dart` is the rejection target — `a` is the
// `testBuilder` default package, making this import the same-package
// violation the validator must catch. The URI is unresolvable outside
// the test harness, hence the suppression.
// ignore: uri_does_not_exist
import 'package:a/sibling.dart';

class Counter {
  @SolidState()
  int value = 0;
}
