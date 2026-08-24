// FIX: `.environment()` omitting `dispose:` for a type with NO `dispose()`
// method (own or via a known disposable base) must NOT receive the
// auto-injected closure — injecting it unconditionally crashes at dispose
// time. `Counter` carries `@SolidState` (forces this file through the main
// lowering pipeline, matching the real-world bug's file shape — a
// Solid-annotated widget file that also injects a plain repository via
// `.environment()`); `AuthRepository` is a plain class with no `dispose()`
// at all and must be left completely unchanged at the call site.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  @SolidState()
  int value = 0;
}

class AuthRepository {
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
    return HomePage().environment<AuthRepository>((_) => AuthRepository());
  }
}
