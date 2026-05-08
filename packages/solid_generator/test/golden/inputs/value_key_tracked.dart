import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class KeyedContainer extends StatelessWidget {
  KeyedContainer({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(counter),
      child: const Text('hi'),
    );
  }
}
