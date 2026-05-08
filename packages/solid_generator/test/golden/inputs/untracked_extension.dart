import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class KeyedContainerUntracked extends StatelessWidget {
  KeyedContainerUntracked({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(counter.untracked),
      child: const Text('hi'),
    );
  }
}
