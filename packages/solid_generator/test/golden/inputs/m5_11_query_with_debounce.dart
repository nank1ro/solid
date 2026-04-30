// M5-11: exercises `debounce:` propagation to `debounceDelay:`.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Searcher extends StatelessWidget {
  Searcher({super.key});

  @SolidQuery(debounce: Duration(milliseconds: 300))
  Future<String> fetchData() async => 'result';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
