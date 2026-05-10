// Rejection suite for self-cycling `@SolidQuery` (SPEC §3.5
// "Auto-tracking of upstream queries"). A query whose body invokes itself
// is rejected at codegen because the lowered Resource would re-run
// indefinitely.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'query_self_cycle_rejected',
    errorContains:
        "@SolidQuery 'fetchSelf' invokes itself in its own body",
  ),
];

void main() {
  runRejectionCases('@SolidQuery self-cycle rejection', _cases);
}
