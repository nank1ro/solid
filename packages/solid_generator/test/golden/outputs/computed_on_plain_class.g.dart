import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  late final doubled = Computed<int>(() => value.value * 2, name: 'doubled');

  @override
  void dispose() {
    doubled.dispose();
    value.dispose();
  }
}
