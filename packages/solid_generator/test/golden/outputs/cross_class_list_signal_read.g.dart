import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Controller implements Disposable {
  final todos = ListSignal<int>([], name: 'todos');

  @override
  void dispose() {
    todos.dispose();
  }
}

class Display extends StatefulWidget {
  const Display({super.key});

  @override
  State<Display> createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
  late final controller = context.read<Controller>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('count: ${controller.todos.length}');
      },
    );
  }
}
