import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Resetter extends StatefulWidget {
  const Resetter({super.key});

  @override
  State<Resetter> createState() => _ResetterState();
}

class _ResetterState extends State<Resetter> {
  final name = Signal<String>('init', name: 'name');

  void reset() {
    setState(() {
      name.value = 'default';
    });
  }

  @override
  Widget build(BuildContext context) => const Placeholder();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}
