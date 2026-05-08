import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Greeting extends StatelessWidget {
  Greeting({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Text('counter is $counter');
  }
}
