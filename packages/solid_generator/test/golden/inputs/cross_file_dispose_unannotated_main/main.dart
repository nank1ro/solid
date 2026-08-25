// Regression fixture for the cross-file auto-dispose bug: `main.dart` carries
// NO `@Solid*` annotation anywhere, so the builder takes the unannotated
// fast path — the RESOLVED `CompilationUnit` is handed straight to
// `addProviderDisposeAtCallSites`. `CitiesController` (imported from
// `controller.dart`) is `@SolidState`-annotated there, so its `lib/` output
// is Solid-lowered and always synthesizes `dispose()` — the auto-dispose
// pass must inject `dispose:` even though the resolved element it can see
// (the pre-lowering source class) has no `dispose()` of its own.
// ignore_for_file: unreachable_from_main

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    const HomePage().environment<CitiesController>((_) => CitiesController()),
  );
}
