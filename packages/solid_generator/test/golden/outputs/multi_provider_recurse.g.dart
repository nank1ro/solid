import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}

class Logger implements Disposable {
  final messages = Signal<int>(0, name: 'messages');

  @override
  void dispose() {
    messages.dispose();
  }
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<Counter>(
          create: (_) => Counter(),
          dispose: (context, provider) => provider.dispose(),
        ),
        Provider<Logger>(
          create: (_) => Logger(),
          dispose: (context, provider) => provider.dispose(),
        ),
      ],
      child: HomePage(),
    ),
  );
}
