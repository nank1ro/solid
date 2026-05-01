import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

abstract class Base {
  String describe();
}

mixin class Tagged {
  String get tag => 'default';
}

abstract class Marker {}

class Sub extends Base with Tagged implements Marker, Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  String describe() => 'sub';

  @override
  void dispose() {
    value.dispose();
  }
}
