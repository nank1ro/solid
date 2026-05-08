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

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    Provider(
      create: (_) => Counter(),
      child: HomePage(),
      dispose: (context, provider) => provider.dispose(),
    ),
  );
}
