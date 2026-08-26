// The FOREIGN, `@SolidState`-bearing `Foo` — deliberately sharing its
// simple name with `consumer.dart`'s own LOCAL plain `Foo` (issue #108 fix
// review finding 1). Only reachable from `consumer.dart` through the
// one-hop extension: `consumer.dart` imports `base.dart`, and `base.dart`
// imports THIS file.
import 'package:solid_annotations/solid_annotations.dart';

class Foo {
  @SolidState()
  String? label;
}
