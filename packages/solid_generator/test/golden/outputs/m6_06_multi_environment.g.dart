import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}

class Logger {
  void log(String message) => print(message);
}

class CounterDisplay extends StatefulWidget {
  CounterDisplay({super.key});

  @override
  State<CounterDisplay> createState() => _CounterDisplayState();
}

class _CounterDisplayState extends State<CounterDisplay> {
  late final counter = context.read<Counter>();
  late final logger = context.read<Logger>();

  @override
  Widget build(BuildContext context) {
    logger.log('build');
    return SignalBuilder(
      builder: (context, child) {
        return Text(counter.value.value.toString());
      },
    );
  }
}
