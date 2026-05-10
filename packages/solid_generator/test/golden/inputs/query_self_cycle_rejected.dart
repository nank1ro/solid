// SPEC §3.5: a `@SolidQuery` whose body invokes itself is rejected at
// codegen because the lowered Resource would re-run indefinitely. The
// reader-level `_rejectSelfCycle` walk fires regardless of whether the
// recursive call sits inside a conditional, a closure, or a deeper
// expression — only block-local shadowing of the method name suppresses
// it (SPEC §5.5).
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class CycleWidget extends StatelessWidget {
  CycleWidget({super.key});

  @SolidQuery()
  Future<int> fetchSelf() async {
    final v = fetchSelf().asReady?.value ?? 0;
    return v + 1;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
