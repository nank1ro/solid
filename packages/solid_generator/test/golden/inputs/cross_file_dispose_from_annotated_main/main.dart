// Regression fixture for the cross-file auto-dispose bug, MAIN ANNOTATED
// PATH variant: `main.dart` DOES carry a `@Solid*` annotation (`Counter`),
// so the builder takes the main lowering path — `addProviderDisposeAtCallSites`
// runs on the ASSEMBLED, re-parsed output with NO resolver available at all
// (see builder.dart's `_renderOutput`). The only way this checker can ever
// recognize `CitiesController` (imported from `controller.dart`) as
// Solid-lowered on this path is the name-based cross-file `classRegistry`
// that `builder.dart::_populateCrossFileTypes` seeds from this file's
// `.environment<T>()` call sites.
// ignore_for_file: unreachable_from_main, prefer_const_constructors_in_immutables

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controller.dart';

class Counter {
  @SolidState()
  int value = 0;
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
    const HomePage().environment<CitiesController>((_) => CitiesController()),
  );
}
