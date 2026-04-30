import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Ticker extends StatefulWidget {
  Ticker({super.key});

  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  late final watchTicks = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'watchTicks');

  @override
  void dispose() {
    watchTicks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
