// Cross-class collection-signal read: `Controller.todos` is a `List<int>`
// `@SolidState` field — lowers to `ListSignal<int>` — and is consumed by
// `Display` via `@SolidEnvironment`. `controller.todos.length` must NOT
// receive a `.value` between the receiver and `.length` (the `ListMixin`
// member is reached through the signal directly). The enclosing `Text`
// must still be wrapped in `SignalBuilder` so the read subscribes.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Controller {
  @SolidState()
  List<int> todos = const [];
}

class Display extends StatelessWidget {
  Display({super.key});

  @SolidEnvironment()
  late Controller controller;

  @override
  Widget build(BuildContext context) {
    return Text('count: ${controller.todos.length}');
  }
}
