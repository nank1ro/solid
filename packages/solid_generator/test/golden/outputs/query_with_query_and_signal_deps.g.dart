import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class ScaledTickReader extends StatefulWidget {
  const ScaledTickReader({super.key});

  @override
  State<ScaledTickReader> createState() => _ScaledTickReaderState();
}

class _ScaledTickReaderState extends State<ScaledTickReader> {
  final divisor = Signal<int>(2, name: 'divisor');
  late final watchTicks = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'watchTicks');
  late final _scaledTickSource = Computed<(int, ResourceState<int>)>(
    () => (divisor.value, watchTicks.state),
    name: '_scaledTickSource',
  );
  late final scaledTick = Resource<double>(
    () async {
      return (watchTicks().asReady?.value ?? 0) / divisor.value.toDouble();
    },
    source: _scaledTickSource,
    name: 'scaledTick',
  );

  @override
  void dispose() {
    scaledTick.dispose();
    _scaledTickSource.dispose();
    watchTicks.dispose();
    divisor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
