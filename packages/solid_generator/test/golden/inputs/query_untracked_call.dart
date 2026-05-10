// SPEC §6.4 query-call form: `<queryName>().untracked` lowers to
// `<queryName>.untrackedState`, bypassing the call entirely. The downstream
// query/effect/getter does NOT subscribe to the upstream's emissions and is
// excluded from `Resource.source:` / Effect / Computed wiring (SPEC §4.8
// rule 5). Subsequent chained members (`.value`, `.asReady?.value`, etc.)
// resolve normally on `ResourceState<T>` via upstream `ResourceExtensions`.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class TickPeeker extends StatelessWidget {
  TickPeeker({super.key});

  @SolidQuery()
  Stream<int> watchTicks() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @SolidQuery()
  Future<int> snapshotOnce() async {
    return watchTicks().untracked.asReady?.value ?? 0;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
