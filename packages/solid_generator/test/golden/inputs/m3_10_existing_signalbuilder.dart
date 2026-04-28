import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class ManualWrapProbe extends StatelessWidget {
  ManualWrapProbe({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) => Text('$counter'),
    );
  }
}
