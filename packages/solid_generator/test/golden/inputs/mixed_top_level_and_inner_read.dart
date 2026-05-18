// Mixed pattern: one signal read at the build method's statement scope
// (unanchored — drives the outer body wrap) and a DIFFERENT signal read
// inside an inner widget expression (anchored — would normally get its
// own inner wrap). Per SPEC §7.6 (mixed-signal nested reads), the inner
// wrap is KEPT because the outer's name-set is not a superset of the
// inner's.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class TwoSignals extends StatelessWidget {
  TwoSignals({super.key});

  @SolidState()
  String header = 'hi';

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    final h = header;
    return Column(
      children: [
        Text(h),
        Text('count is $counter'),
      ],
    );
  }
}
