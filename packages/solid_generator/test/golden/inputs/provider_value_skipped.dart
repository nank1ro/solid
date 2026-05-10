// `Provider<T>.value(...)` does not own its instance and
// takes no `dispose:` — the visitor must skip the named-ctor form.

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    Provider<int>.value(
      value: 0,
      child: const HomePage(),
    ),
  );
}
