import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidQuery()
  Future<int> get fetchCount async => 0;
}
