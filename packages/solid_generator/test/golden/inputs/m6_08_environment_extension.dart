import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {}

class Foo extends StatelessWidget {
  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return const SizedBox().environment<Counter>(
      (_) => Counter(),
      dispose: (_, c) => {},
    );
  }
}
