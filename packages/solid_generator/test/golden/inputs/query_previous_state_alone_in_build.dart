// A build() reading `<query>.previousState?.asReady?.value` with NO
// `<query>()` call anywhere else in the same build. Proves the
// `.previousState` tear-off ALONE is recognized as a tracked read — before
// this fix, the only tracked-read detection for a query was the CALL form
// (`<query>()`); a build reading solely the `.previousState` tear-off form
// got no `SignalBuilder` wrap and no `flutter_solidart` import, even
// though `Resource.previousState` is genuinely reactive at the signal
// level (`ReadSignal.previousValue` reports observed).
// ignore_for_file: prefer_const_constructors_in_immutables
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class CounterScreen extends StatelessWidget {
  CounterScreen({super.key});

  @SolidQuery()
  Future<int> fetchCount() async => 0;

  @override
  Widget build(BuildContext context) {
    return Text('${fetchCount.previousState?.asReady?.value}');
  }
}
