import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class TickCombiner extends StatefulWidget {
  const TickCombiner({super.key});

  @override
  State<TickCombiner> createState() => _TickCombinerState();
}

class _TickCombinerState extends State<TickCombiner> {
  late final ticksA = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'ticksA');
  late final ticksB = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 2), (i) => i * 10);
  }, name: 'ticksB');
  late final _combinedSource =
      Computed<(ResourceState<int>, ResourceState<int>)>(
        () => (ticksA.state, ticksB.state),
        name: '_combinedSource',
      );
  late final combined = Resource<int>(
    () async {
      final a = ticksA().asReady?.value ?? 0;
      final b = ticksB().asReady?.value ?? 0;
      return a + b;
    },
    source: _combinedSource,
    name: 'combined',
  );

  @override
  void dispose() {
    combined.dispose();
    _combinedSource.dispose();
    ticksB.dispose();
    ticksA.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
