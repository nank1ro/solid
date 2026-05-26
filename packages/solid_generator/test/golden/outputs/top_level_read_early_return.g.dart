import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeter extends StatefulWidget {
  const Greeter({super.key});

  @override
  State<Greeter> createState() => _GreeterState();
}

class _GreeterState extends State<Greeter> {
  final message = Signal<String?>(null, name: 'message');

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        final m = message.value;
        if (m == null) {
          return const Center(child: Text('no message'));
        }
        return Center(child: Text(m));
      },
    );
  }
}
