// Regression fixture for the cross-file registry decoy-collision bug: a
// same-simple-name decoy class with zero `@SolidState` members, imported
// BEFORE the real annotated class of the same name, must not consume the
// wanted type name in `builder.dart::_populateCrossFileTypes` and strand the
// real class unrecognized.
//
// The assertion that actually proves the REGISTRY (not some other fallback)
// recognized `UnitsController` is the `@SolidEnvironment` cross-class `.value`
// rewrite below: `controller.count` inside `build` must become
// `controller.count.value`. That rewrite (`value_rewriter.dart`'s
// `_maybeRewriteCrossClass*`) is a direct `classRegistry` map lookup with NO
// secondary/fallback mechanism of any kind — unlike the auto-dispose
// call-site check (see the sibling `cross_file_dispose_*` fixtures), which
// on the main-lowering path falls back to "inject anyway" (clause 4) for ANY
// unrecognized cross-file type, so dispose injection alone can't distinguish
// "the registry correctly recognized `UnitsController`" from "the registry
// missed it entirely but the conservative default injected anyway". A
// missing `.value` rewrite here can ONLY be explained by the registry never
// having learned `UnitsController`'s `@SolidState` members — i.e. exactly
// the decoy-collision bug.
// ignore_for_file: unused_import

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'decoy.dart' as decoy;
import 'controller.dart';

class Display extends StatelessWidget {
  Display({super.key});

  @SolidEnvironment()
  late UnitsController controller;

  @override
  Widget build(BuildContext context) {
    return Text('count: ${controller.count}');
  }
}
