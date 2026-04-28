import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class ShadowProbe extends StatefulWidget {
  ShadowProbe({super.key});

  @override
  State<ShadowProbe> createState() => _ShadowProbeState();
}

class _ShadowProbeState extends State<ShadowProbe> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

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
