import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  final counter = Signal<int>(0, name: 'counter');
  late final logCounter = Effect(() {
    print('Counter: ${counter.value}');
  }, name: 'logCounter');

  @override
  void initState() {
    super.initState();
    logCounter;
    debugPrint('init');
  }

  @override
  void dispose() {
    logCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
