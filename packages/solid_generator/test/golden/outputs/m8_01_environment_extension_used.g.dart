import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  int n = 0;
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final n = Signal<int>(0, name: 'n');

  @override
  void dispose() {
    n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder().environment<Counter>((_) => Counter());
  }
}
