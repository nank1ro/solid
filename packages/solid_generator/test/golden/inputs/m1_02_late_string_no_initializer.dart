import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Greeting extends StatelessWidget {
  Greeting({super.key});

  @SolidState()
  late String text;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
