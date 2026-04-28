import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class SearchBox extends StatelessWidget {
  SearchBox({super.key});

  final controller = TextEditingController();

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(controller.value.text),
        Text('count: $counter'),
      ],
    );
  }
}
