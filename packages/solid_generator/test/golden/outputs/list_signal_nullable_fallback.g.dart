import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class NullableListProbe extends StatefulWidget {
  const NullableListProbe({super.key});

  @override
  State<NullableListProbe> createState() => _NullableListProbeState();
}

class _NullableListProbeState extends State<NullableListProbe> {
  final xs = Signal<List<int>?>(null, name: 'xs');

  @override
  void dispose() {
    xs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
