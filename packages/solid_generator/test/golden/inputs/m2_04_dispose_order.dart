import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class DisposeOrder extends StatelessWidget {
  DisposeOrder({super.key});

  @SolidState()
  int count = 0;

  @SolidState()
  String label = '';

  @SolidState()
  int get summary => count * 2;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
