import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Repo implements Disposable {
  late final items = Resource<List<String>>(
    () async => const ['a'],
    name: 'items',
  );

  @override
  void dispose() {
    items.dispose();
  }
}
