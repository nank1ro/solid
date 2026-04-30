import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidQuery()
  Future<int> fetchOne(int id) async => id;
}
