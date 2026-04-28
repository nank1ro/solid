// Rejection suite for M3-12: the v1 untracked() function-call form (SPEC §6.4).
// Writing `untracked(() => ...)` produces a CodeGenerationError directing
// the user to the extension getter at the call site.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm3_12_untracked_function_call_rejected',
    errorContains: 'untracked(() => ...) is no longer supported (SPEC §6.4)',
  ),
];

void main() {
  runRejectionCases('m3_12 untracked() function-call rejection', _cases);
}
