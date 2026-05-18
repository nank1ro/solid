import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class TwoSignals extends StatefulWidget {
  const TwoSignals({super.key});

  @override
  State<TwoSignals> createState() => _TwoSignalsState();
}

class _TwoSignalsState extends State<TwoSignals> {
  final header = Signal<String>('hi', name: 'header');
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        final h = header.value;
        return Column(
          children: [
            Text(h),
            SignalBuilder(
              builder: (context, child) {
                return Text('count is ${counter.value}');
              },
            ),
          ],
        );
      },
    );
  }
}
