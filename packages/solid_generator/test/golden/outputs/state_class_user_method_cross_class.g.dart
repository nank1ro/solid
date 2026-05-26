import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class SomeController implements Disposable {
  final name = Signal<String>('', name: 'name');

  @override
  void dispose() {
    name.dispose();
  }
}

class Resetter extends StatefulWidget {
  const Resetter({super.key});

  @override
  State<Resetter> createState() => _ResetterState();
}

class _ResetterState extends State<Resetter> {
  late final ctrl = context.read<SomeController>();

  void reset() {
    ctrl.name.value = 'default';
  }

  @override
  Widget build(BuildContext context) => const Placeholder();

  @override
  void dispose() {
    super.dispose();
  }
}
