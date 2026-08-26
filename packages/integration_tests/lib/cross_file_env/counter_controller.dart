import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  final history = ListSignal<int>([], name: 'history');

  @override
  void dispose() {
    history.dispose();
    value.dispose();
  }
}
