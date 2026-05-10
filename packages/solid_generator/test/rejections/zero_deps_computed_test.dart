// Rejection suite for zero-deps Computed.
// A `@SolidState` getter whose body references no reactive declaration
// must be rejected at build time with the appropriate error message.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'computed_no_deps_rejected',
    errorContains: "getter 'constantFive' has no reactive dependencies",
  ),
];

void main() {
  runRejectionCases('zero-deps Computed rejection', _cases);
}
