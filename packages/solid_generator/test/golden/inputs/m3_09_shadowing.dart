import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class ShadowProbe extends StatelessWidget {
  ShadowProbe({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final counter = 'local';
        return Text(counter);
      },
    );
  }
}
