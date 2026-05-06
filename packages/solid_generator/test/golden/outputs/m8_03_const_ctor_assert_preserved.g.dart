import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeter extends StatefulWidget {
  Greeter({super.key, required this.label})
    : assert(label.isNotEmpty, 'label must not be empty');

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
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('${widget.label} ${counter.value}');
      },
    );
  }
}
