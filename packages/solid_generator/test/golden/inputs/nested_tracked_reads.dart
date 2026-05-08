import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class NestedCounter extends StatelessWidget {
  NestedCounter({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('top: $counter'),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('nested: $counter'),
        ),
      ],
    );
  }
}
