import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidQuery()
  Future<int> fetchCount() => Future.value(0);
}
