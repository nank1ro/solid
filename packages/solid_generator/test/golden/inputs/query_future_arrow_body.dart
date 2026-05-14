// `@SolidQuery` on a `Future<T>`-returning method using an expression body
// without `async`. The arrow body produces a Future directly, which is valid
// Dart — `await` is only required when the body actually awaits a value.
// The generator should accept this shape unchanged.

import 'package:solid_annotations/solid_annotations.dart';

class Answers {
  @SolidQuery()
  Future<int> answer() => Future.value(42);
}
