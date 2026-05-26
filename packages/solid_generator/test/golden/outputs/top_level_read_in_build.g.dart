import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage> {
  final name = Signal<String>('world', name: 'name');

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        final n = name.value;
        return Text('hello $n');
      },
    );
  }
}
