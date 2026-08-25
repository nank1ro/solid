import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class UnitsController implements Disposable {
  final count = Signal<int>(0, name: 'count');

  @override
  void dispose() {
    count.dispose();
  }
}
