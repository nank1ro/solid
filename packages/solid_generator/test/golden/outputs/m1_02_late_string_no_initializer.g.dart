import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeting extends StatefulWidget {
  Greeting({super.key});

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
  late final text = Signal<String>.lazy(name: 'text');

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
