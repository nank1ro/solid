import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class KeyedContainer extends StatefulWidget {
  KeyedContainer({super.key});

  @override
  State<KeyedContainer> createState() => _KeyedContainerState();
}

class _KeyedContainerState extends State<KeyedContainer> {
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
        return Container(key: ValueKey(counter.value), child: const Text('hi'));
      },
    );
  }
}
