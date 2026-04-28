import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class NestedCounter extends StatefulWidget {
  NestedCounter({super.key});

  @override
  State<NestedCounter> createState() => _NestedCounterState();
}

class _NestedCounterState extends State<NestedCounter> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('top: ${counter.value}');
          },
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SignalBuilder(
            builder: (context, child) {
              return Text('nested: ${counter.value}');
            },
          ),
        ),
      ],
    );
  }
}
