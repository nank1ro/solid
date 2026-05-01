import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Comparable<Counter> {
  @SolidState()
  int value = 0;

  @override
  int compareTo(Counter other) => value - other.value;
}
