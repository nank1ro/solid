// Rejection suite for `const` collection initializers on `@SolidState`
// fields. A `const` literal is unmodifiable; the lowered ListSignal /
// SetSignal / MapSignal forward writes through their mixins and would
// throw `UnsupportedError` on the first mutation. The generator catches
// this at build time so the failure surfaces immediately.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'solid_state_const_collection_rejected',
    errorContains: '`const` initializer',
  ),
];

void main() {
  runRejectionCases('@SolidState const collection rejection', _cases);
}
