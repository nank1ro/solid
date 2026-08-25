import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class PlainHelper {
  int count = 0;
}

class Reporter implements Disposable {
  Reporter(this._helper);

  final PlainHelper _helper;

  final calls = Signal<int>(0, name: 'calls');

  int report() {
    calls.value = calls.value + 1;
    return _helper.count;
  }

  @override
  void dispose() {
    calls.dispose();
  }
}
