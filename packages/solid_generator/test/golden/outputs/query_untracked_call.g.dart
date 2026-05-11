import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class TickPeeker extends StatefulWidget {
  const TickPeeker({super.key});

  @override
  State<TickPeeker> createState() => _TickPeekerState();
}

class _TickPeekerState extends State<TickPeeker> {
  late final watchTicks = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'watchTicks');
  late final snapshotOnce = Resource<int>(() async {
    return watchTicks.untrackedState.asReady?.value ?? 0;
  }, name: 'snapshotOnce');

  @override
  void dispose() {
    snapshotOnce.dispose();
    watchTicks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
