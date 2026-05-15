import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class WithHelper extends StatefulWidget {
  const WithHelper({super.key});

  @override
  State<WithHelper> createState() => _WithHelperState();
}

class _WithHelperState extends State<WithHelper> {
  Timer? _timer;

  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context, child) {
      return Text(_format(counter.value));
    },
  );

  String _format(int x) => 'x: $x';
}
