// SPEC §3.5 query example: an async fetcher that delays before returning.
// `Future.delayed` returns `Future<void>` here — explicit type-arg silences
// `inference_failure_on_instance_creation` from the strict golden lints.
// The `Greeter` widget has only a query (no mutable `@SolidState` field) so
// its constructor could be const before lowering, but the SPEC §2 source
// model writes user-facing widgets with non-const constructors uniformly.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Greeter extends StatelessWidget {
  Greeter({super.key});

  @SolidQuery()
  Future<String> fetchData() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'fetched';
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
