import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class TickReader extends StatefulWidget {
  const TickReader({super.key});

  @override
  State<TickReader> createState() => _TickReaderState();
}

class _TickReaderState extends State<TickReader> {
  late final watchTicks = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'watchTicks');
  late final halveLatestTick = Resource<double>(
    () async {
      return (watchTicks().asReady?.value ?? 0).toDouble() / 2.0;
    },
    source: watchTicks,
    name: 'halveLatestTick',
  );

  @override
  void dispose() {
    halveLatestTick.dispose();
    watchTicks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
