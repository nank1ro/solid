// A top-level read used to gate an early return — the canonical
// `final c = sig; if (c == null) return …; return …;` pattern from the
// chat example's `MessagePane`. The synthesized outer SignalBuilder must
// wrap the block body INCLUDING the early-return so that re-evaluation
// of the read on signal change re-runs the conditional and swaps the
// returned widget.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Greeter extends StatelessWidget {
  Greeter({super.key});

  @SolidState()
  String? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) {
      return const Center(child: Text('no message'));
    }
    return Center(child: Text(m));
  }
}
