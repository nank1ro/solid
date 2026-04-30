// SPEC §4.8 rule 3: a `<query>().when(...)` chain in build is the canonical
// reactive call site. The chain is byte-identical between input and output;
// the SignalBuilder wrap is the only delta. UserScreen has only a query
// (no mutable @SolidState field) so its constructor could be const before
// lowering, but the SPEC §2 source model writes user-facing widgets with
// non-const constructors uniformly. The `loading: () => const CircularProgress
// Indicator()` closure intentionally preserves the const-construction wrapper
// (a const tear-off is not expressible in Dart), so `unnecessary_lambdas` is
// silenced for this file.
// ignore_for_file: prefer_const_constructors_in_immutables, unnecessary_lambdas

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class UserScreen extends StatelessWidget {
  UserScreen({super.key});

  @SolidQuery()
  Future<String> fetchName() async => 'Alice';

  @override
  Widget build(BuildContext context) {
    return fetchName().when(
      ready: (name) => Text(name),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('error: $e'),
    );
  }
}
