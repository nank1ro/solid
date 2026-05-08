import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class BuilderProbe extends StatelessWidget {
  BuilderProbe({super.key});

  @SolidState()
  String label = '';

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Text(label);
      },
    );
  }
}
