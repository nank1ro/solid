import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Dashboard extends StatefulWidget {
  Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final counter = Signal<int>(0, name: 'counter');
  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );
  late final logBoth = Effect(() {
    print('${counter.value} / ${doubleCounter.value}');
  }, name: 'logBoth');
  late final fetchSnapshot = Resource<int>(
    () async => 0,
    name: 'fetchSnapshot',
  );

  @override
  void initState() {
    super.initState();
    logBoth;
  }

  @override
  void dispose() {
    fetchSnapshot.dispose();
    logBoth.dispose();
    doubleCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
