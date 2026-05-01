// Rejection suite for M6-08: same-class provide-and-consume anti-pattern.
//
// A class that both consumes (`@SolidEnvironment() late T x;`) and provides
// the same `T` to its own subtree (via `Provider<T>(...)` constructor or
// `.environment<T>(...)` extension in `build`) is rejected at build time
// per SPEC §3.6.
//
// Cases:
//   - Provider<T>(...) constructor call in build
//   - .environment<T>(...) extension call in build

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm6_08_provider_widget',
    errorContains:
        '@SolidEnvironment and Provider for the same type in one class',
  ),
  (
    name: 'm6_08_environment_extension',
    errorContains:
        '@SolidEnvironment and Provider for the same type in one class',
  ),
];

void main() {
  runRejectionCases('m6_08 same-class provide-and-consume', _cases);
}
