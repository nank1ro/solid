import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Model implements Disposable {
  final gate = Signal<int>(0, name: 'gate');

  @override
  void dispose() {
    gate.dispose();
  }
}

class Collide extends StatelessWidget {
  const Collide({required this.model, required this.gate, super.key});

  final Model model;
  final Signal<int> gate;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Tooltip(
          message: 'managed: ${model.gate.value}',
          child: SignalBuilder(
            builder: (context, child) {
              return Text('foreign: ${gate.value}');
            },
          ),
        );
      },
    );
  }
}

class NoCollide extends StatelessWidget {
  const NoCollide({required this.model, required this.other, super.key});

  final Model model;
  final Signal<int> other;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Tooltip(
          message: 'managed: ${model.gate.value}',
          child: SignalBuilder(
            builder: (context, child) {
              return Text('foreign: ${other.value}');
            },
          ),
        );
      },
    );
  }
}
