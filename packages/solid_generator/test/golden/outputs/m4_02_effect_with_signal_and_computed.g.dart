import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class EffectWithDeps extends StatefulWidget {
  EffectWithDeps({super.key});

  @override
  State<EffectWithDeps> createState() => _EffectWithDepsState();
}

class _EffectWithDepsState extends State<EffectWithDeps> {
  final counter = Signal<int>(0, name: 'counter');
  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );
  late final logBoth = Effect(() {
    print('${counter.value} / ${doubleCounter.value}');
  }, name: 'logBoth');

  @override
  void initState() {
    super.initState();
    logBoth;
  }

  @override
  void dispose() {
    logBoth.dispose();
    doubleCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
