import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Answers implements Disposable {
  late final answer = Resource<int>(() => Future.value(42), name: 'answer');

  @override
  void dispose() {
    answer.dispose();
  }
}
