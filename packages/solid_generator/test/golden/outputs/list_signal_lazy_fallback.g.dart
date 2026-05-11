import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class LateListProbe extends StatefulWidget {
  const LateListProbe({super.key});

  @override
  State<LateListProbe> createState() => _LateListProbeState();
}

class _LateListProbeState extends State<LateListProbe> {
  late final xs = Signal<List<int>>.lazy(name: 'xs');

  @override
  void dispose() {
    xs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
