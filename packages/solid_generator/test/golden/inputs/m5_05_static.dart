import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidQuery()
  static Future<int> fetchCount() async => 0;
}
