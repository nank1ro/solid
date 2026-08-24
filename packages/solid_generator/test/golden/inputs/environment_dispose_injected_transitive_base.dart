// FIX: the same-file known-disposable-base check must walk the `extends`
// chain TRANSITIVELY, not just the created class's own clause.
// `SessionController` doesn't itself `extends ChangeNotifier` — it extends
// `SessionControllerBase`, which is the class that names `ChangeNotifier`.
// `Counter` carries `@SolidState` (forces the main lowering pipeline, same
// as the sibling `environment_dispose_injected_changenotifier` golden).
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  @SolidState()
  int value = 0;
}

class SessionControllerBase extends ChangeNotifier {
  String? token;
}

class SessionController extends SessionControllerBase {
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
