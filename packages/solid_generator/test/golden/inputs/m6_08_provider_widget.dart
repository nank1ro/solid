import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {}

class Foo extends StatelessWidget {
  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Provider<Counter>(
      create: (_) => Counter(),
      child: const SizedBox(),
    );
  }
}
