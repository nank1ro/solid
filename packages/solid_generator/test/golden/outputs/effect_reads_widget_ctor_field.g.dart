import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class TempLogger extends StatefulWidget {
  const TempLogger({super.key, required this.label});

  final String label;

  @override
  State<TempLogger> createState() => _TempLoggerState();
}

class _TempLoggerState extends State<TempLogger> {
  final celsius = Signal<double>(0, name: 'celsius');
  late final logTemp = Effect(() {
    debugPrint('${widget.label} is at ${celsius.value}');
  }, name: 'logTemp');

  @override
  void initState() {
    super.initState();
    logTemp;
  }

  @override
  void dispose() {
    logTemp.dispose();
    celsius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context, child) {
      return Text('${celsius.value}');
    },
  );
}
