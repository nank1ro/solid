import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Meter implements Disposable {
  final wrongField = Signal<int>(0, name: 'wrongField');

  @override
  void dispose() {
    wrongField.dispose();
  }
}
