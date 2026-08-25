import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Address implements Disposable {
  final line1 = Signal<String?>(null, name: 'line1');

  @override
  void dispose() {
    line1.dispose();
  }
}
