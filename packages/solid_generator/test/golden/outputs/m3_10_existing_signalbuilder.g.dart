import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class ManualWrapProbe extends StatefulWidget {
  ManualWrapProbe({super.key});

  @override
  State<ManualWrapProbe> createState() => _ManualWrapProbeState();
}

class _ManualWrapProbeState extends State<ManualWrapProbe> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(builder: (context, child) => Text('${counter.value}'));
  }
}
