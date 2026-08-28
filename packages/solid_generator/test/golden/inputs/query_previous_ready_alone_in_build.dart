// A build() reading `<query>.previousReady?.value` with NO `<query>()` call
// anywhere else in the same build. Proves the `.previousReady` tear-off ALONE
// is recognized as a tracked read — the same recognition as `.previousState`,
// generalized to the retained-state getter set (previousState / previousReady /
// previousError). `previousReady` lowers to `Resource.previousReady`
// (a `ResourceReady<T>?`), so `.value` is read directly, not via `.asReady`.
// ignore_for_file: prefer_const_constructors_in_immutables
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class CounterScreen extends StatelessWidget {
  CounterScreen({super.key});

  @SolidQuery()
  Future<int> fetchCount() async => 0;

  @override
  Widget build(BuildContext context) {
    return Text('${fetchCount.previousReady?.value}');
  }
}
