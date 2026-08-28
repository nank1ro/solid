import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Repo implements Disposable {
  Future<List<String>> items() async => const ['b'];

  late final otherQuery = Resource<int>(() async => 0, name: 'otherQuery');

  @override
  void dispose() {
    otherQuery.dispose();
  }
}
