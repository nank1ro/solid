import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class CounterButton extends StatelessWidget {
  CounterButton({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => counter++,
      child: const Icon(Icons.add),
    );
  }
}
