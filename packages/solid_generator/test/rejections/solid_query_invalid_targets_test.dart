// Rejection suite for invalid `@SolidQuery` placements per SPEC §3.5.
//
// Cases ordered to mirror the SPEC §3.5 bullet list: non-Future/Stream return
// → Future-without-async body → parameterized → static → abstract/external →
// getter → setter → top-level function. Class fields are NOT rejected: a
// field initializer expression (e.g. `Future.value(0)`) is a valid fetcher
// shape — the lowering wraps it as `Resource<T>(fetcher: () => <init>)`.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'non_future_return',
    errorContains:
        '@SolidQuery cannot be applied to a non-Future/Stream method',
  ),
  (
    name: 'future_without_async',
    errorContains:
        '@SolidQuery cannot be applied to a method whose body keyword '
        'does not match the return type',
  ),
  (
    name: 'solid_query_parameterized',
    errorContains: '@SolidQuery cannot be applied to a parameterized method',
  ),
  (
    name: 'solid_query_static',
    errorContains: '@SolidQuery cannot be applied to a static method',
  ),
  (
    name: 'solid_query_abstract',
    errorContains: '@SolidQuery cannot be applied to an abstract method',
  ),
  (
    name: 'solid_query_getter',
    errorContains: '@SolidQuery cannot be applied to a getter',
  ),
  (
    name: 'solid_query_setter',
    errorContains: '@SolidQuery cannot be applied to a setter',
  ),
  (
    name: 'solid_query_top_level',
    errorContains: '@SolidQuery cannot be applied to a top-level function',
  ),
];

void main() {
  runRejectionCases('invalid @SolidQuery targets', _cases);
}
