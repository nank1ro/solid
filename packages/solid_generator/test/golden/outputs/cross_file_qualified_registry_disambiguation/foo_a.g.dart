import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Foo implements Disposable {
  final label = Signal<String?>(null, name: 'label');

  @override
  void dispose() {
    label.dispose();
  }
}
