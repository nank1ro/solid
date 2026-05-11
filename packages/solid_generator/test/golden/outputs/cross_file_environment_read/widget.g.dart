import 'package:a/cross_file_environment_read/controllers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';

class Display extends StatefulWidget {
  const Display({super.key});

  @override
  State<Display> createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
  late final counter = context.read<Counter>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('value: ${counter.value.value}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('history-len: ${counter.history.length}');
          },
        ),
      ],
    );
  }
}
