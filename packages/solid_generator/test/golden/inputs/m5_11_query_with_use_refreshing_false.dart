// M5-11: exercises `useRefreshing: false` propagation. The default `true` is
// omitted from emitted output (upstream `Resource` default).
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Loader extends StatelessWidget {
  Loader({super.key});

  @SolidQuery(useRefreshing: false)
  Future<String> fetchData() async => 'result';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
