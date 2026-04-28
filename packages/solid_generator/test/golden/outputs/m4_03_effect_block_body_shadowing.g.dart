import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class EffectShadowing extends StatefulWidget {
  EffectShadowing({super.key});

  @override
  State<EffectShadowing> createState() => _EffectShadowingState();
}

class _EffectShadowingState extends State<EffectShadowing> {
  final counter = Signal<int>(0, name: 'counter');
  late final logCounter = Effect(() {
    print('outer: ${counter.value}');
    {
      const counter = 'shadowed';
      print('inner: $counter');
    }
  }, name: 'logCounter');

  @override
  void dispose() {
    logCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
