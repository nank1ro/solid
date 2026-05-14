import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'types.dart';

class Settings implements Disposable {
  final unit = Signal<Unit>(Unit.a, name: 'unit');

  @override
  void dispose() {
    unit.dispose();
  }
}
