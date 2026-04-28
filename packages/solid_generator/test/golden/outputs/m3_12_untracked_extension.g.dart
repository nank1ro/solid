import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class KeyedContainerUntracked extends StatefulWidget {
  KeyedContainerUntracked({super.key});

  @override
  State<KeyedContainerUntracked> createState() =>
      _KeyedContainerUntrackedState();
}

class _KeyedContainerUntrackedState extends State<KeyedContainerUntracked> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(counter.untrackedValue),
      child: const Text('hi'),
    );
  }
}
