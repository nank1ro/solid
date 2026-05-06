import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeter extends StatefulWidget {
  const Greeter.named({super.key}) : label = 'Named';

  final String label;

  @override
  State<Greeter> createState() => _GreeterState();
}

class _GreeterState extends State<Greeter> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context, child) {
      return Text('$label ${counter.value}');
    },
  );
}
