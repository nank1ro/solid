import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Widget1 extends StatefulWidget {
  const Widget1({super.key});

  @override
  State<Widget1> createState() => _Widget1State();
}

class _Widget1State extends State<Widget1> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context, child) {
      return Text('${counter.value}');
    },
  );
}
