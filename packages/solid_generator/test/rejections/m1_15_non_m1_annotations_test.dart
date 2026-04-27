// Rejection suite for M1-15: reserved annotations from SPEC §3.2 + §13.
// Each case asserts that placing `@SolidEffect`, `@SolidQuery`, or
// `@SolidEnvironment` anywhere in a source file produces a build-time error
// quoting the SPEC §3.2 phrase verbatim.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm1_15_effect',
    errorContains:
        '@SolidEffect is not yet implemented; '
        'scheduled for a later v2 milestone',
  ),
  (
    name: 'm1_15_query',
    errorContains:
        '@SolidQuery is not yet implemented; '
        'scheduled for a later v2 milestone',
  ),
  (
    name: 'm1_15_environment',
    errorContains:
        '@SolidEnvironment is not yet implemented; '
        'scheduled for a later v2 milestone',
  ),
];

void main() {
  runRejectionCases('m1_15 reserved annotations rejection', _cases);
}
