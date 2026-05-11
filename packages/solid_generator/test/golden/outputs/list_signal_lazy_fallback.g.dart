import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class LateCollectionProbe extends StatefulWidget {
  const LateCollectionProbe({super.key});

  @override
  State<LateCollectionProbe> createState() => _LateCollectionProbeState();
}

class _LateCollectionProbeState extends State<LateCollectionProbe> {
  late final xs = ListSignal<int>(const <int>[], name: 'xs');
  late final tags = SetSignal<String>(const <String>{}, name: 'tags');
  late final hits = MapSignal<String, int>(const <String, int>{}, name: 'hits');

  @override
  void dispose() {
    hits.dispose();
    tags.dispose();
    xs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
