// Rejection suite for M5-05: invalid `@SolidQuery` placements per SPEC §3.5.
//
// Cases ordered to mirror the SPEC §3.5 bullet list: non-Future/Stream return
// → Future-without-async body → parameterized → static → abstract/external →
// getter → setter → top-level function → field.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm5_05_non_future_return',
    errorContains:
        '@SolidQuery cannot be applied to a non-Future/Stream method',
  ),
  (
    name: 'm5_05_future_without_async',
    errorContains:
        '@SolidQuery cannot be applied to a method whose body keyword '
        'does not match the return type',
  ),
  (
    name: 'm5_05_parameterized',
    errorContains: '@SolidQuery cannot be applied to a parameterized method',
  ),
  (
    name: 'm5_05_static',
    errorContains: '@SolidQuery cannot be applied to a static method',
  ),
  (
    name: 'm5_05_abstract',
    errorContains: '@SolidQuery cannot be applied to an abstract method',
  ),
  (
    name: 'm5_05_getter',
    errorContains: '@SolidQuery cannot be applied to a getter',
  ),
  (
    name: 'm5_05_setter',
    errorContains: '@SolidQuery cannot be applied to a setter',
  ),
  (
    name: 'm5_05_top_level',
    errorContains: '@SolidQuery cannot be applied to a top-level function',
  ),
  (
    name: 'm5_05_field',
    errorContains: '@SolidQuery cannot be applied to a field',
  ),
];

void main() {
  runRejectionCases('m5_05 invalid @SolidQuery targets', _cases);
}
