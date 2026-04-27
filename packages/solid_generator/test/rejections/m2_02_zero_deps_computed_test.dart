// Rejection suite for M2-02: zero-deps Computed (SPEC §4.5).
// A `@SolidState` getter whose body references no reactive declaration
// must be rejected at build time with the SPEC §4.5 error message.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm2_02_computed_no_deps_rejected',
    errorContains: "getter 'constantFive' has no reactive dependencies",
  ),
];

void main() {
  runRejectionCases('m2_02 zero-deps Computed rejection', _cases);
}
