// FIX: `.environment()` omitting `dispose:` for a type with NO OWN
// `dispose()` declaration but that INHERITS one from a known disposable base
// (`ChangeNotifier`) must still receive the auto-injected closure — the
// type-aware gate checks the inheritance chain, not just the class's own
// members. `Counter` carries `@SolidState` (forces the main lowering
// pipeline, same as the sibling `..._no_dispose_method` golden).
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  @SolidState()
  int value = 0;
}

class SessionController extends ChangeNotifier {
  String? session;
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class App extends StatelessWidget {
  App({super.key});

  @override
  Widget build(BuildContext context) {
    return HomePage().environment<SessionController>(
      (_) => SessionController(),
    );
  }
}
