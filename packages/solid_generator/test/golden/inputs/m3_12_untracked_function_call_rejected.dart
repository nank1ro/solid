import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class LegacyUsage extends StatelessWidget {
  LegacyUsage({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Text('Static: ${untracked(() => counter)}');
  }
}
