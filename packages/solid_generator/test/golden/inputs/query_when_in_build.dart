// SPEC §4.8 rule 3 + §7: a `<query>().when(...)` chain is wrapped in
// SignalBuilder while the chain itself is byte-identical input/output. The
// `loading:` lambda preserves a const-constructed widget (Dart has no const
// tear-off form), so `unnecessary_lambdas` is silenced.
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
