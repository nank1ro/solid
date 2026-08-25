import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'remote_address.dart';

class Address {
  Address(this.line1);

  final String line1;
}

class Shipping implements Disposable {
  Shipping(this.address);

  final Address address;

  final loadCount = Signal<int>(0, name: 'loadCount');

  String describe() {
    loadCount.value = loadCount.value + 1;
    return address.line1;
  }

  @override
  void dispose() {
    loadCount.dispose();
  }
}
