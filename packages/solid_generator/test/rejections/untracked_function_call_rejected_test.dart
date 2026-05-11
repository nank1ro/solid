// Rejection suite for the untracked() function-call form. Writing
// `untracked(() => ...)` produces a CodeGenerationError directing the user
// to the extension getter at the call site.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'untracked_function_call_rejected',
    errorContains: 'untracked(() => ...) is not supported',
  ),
];

void main() {
  runRejectionCases('untracked() function-call rejection', _cases);
}
