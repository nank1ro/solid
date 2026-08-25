import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'repo.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    const HomePage().environment<AuthRepository>(
      (_) => AuthRepository(),
      dispose: (context, provider) => provider.dispose(),
    ),
  );
}
