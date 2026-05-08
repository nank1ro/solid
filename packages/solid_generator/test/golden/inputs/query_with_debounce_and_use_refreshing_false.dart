// SPEC §3.5 / §4.8 rule 9: both annotation parameters combine; emitted order
// is closure (positional), source:, debounceDelay:, useRefreshing:, name:.
// This case has no tracked signals — the source: arg is absent, so the
// adjacency between debounceDelay: and useRefreshing: is exercised directly.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Combined extends StatelessWidget {
  Combined({super.key});

  @SolidQuery(debounce: Duration(milliseconds: 300), useRefreshing: false)
  Future<String> fetchData() async => 'result';

  @override
  Widget build(BuildContext context) => const Placeholder();
}
