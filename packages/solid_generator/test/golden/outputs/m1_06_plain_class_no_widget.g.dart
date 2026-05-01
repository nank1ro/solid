import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  final label = Signal<String>('', name: 'label');

  @override
  void dispose() {
    label.dispose();
    value.dispose();
  }
}
