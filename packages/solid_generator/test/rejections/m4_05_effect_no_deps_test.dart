// Rejection suite for M4-05: zero-deps Effect (SPEC §3.4).
// An `@SolidEffect` method whose body references no reactive declaration
// must be rejected at build time with the SPEC §3.4 error message.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm4_05_effect_no_deps_rejected',
    errorContains: "effect 'doThing' has no reactive dependencies",
  ),
];

void main() {
  runRejectionCases('m4_05 zero-deps Effect rejection', _cases);
}
