// Rejection suite for M1-15: reserved annotations from SPEC §3.2 + §13.
// Each case asserts that placing `@SolidEnvironment` anywhere in a source
// file produces a build-time error quoting the SPEC §3.2 phrase verbatim.
// `@SolidEffect` shipped in M4 and is no longer reserved (M4-06 /
// pulled-into-M4-01); `@SolidQuery` shipped in M5 and is no longer reserved
// (M5-01) — the former rejection case migrated to a positive M5-01 golden.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
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
