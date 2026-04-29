// Rejection suite for M4-04: invalid `@SolidEffect` placements per SPEC §3.4.

import '../integration/golden_helpers.dart';

/// Each case pairs a fixture name with the SPEC §3.4 phrase the resulting
/// error must contain. Cases ordered to mirror the SPEC §3.4 bullet list:
/// parameterized → non-void → static → abstract/external → getter → setter →
/// top-level function → field.
const List<({String name, String errorContains})> _cases = [
  (
    name: 'm4_04_parameterized',
    errorContains: '@SolidEffect cannot be applied to a parameterized method',
  ),
  (
    name: 'm4_04_non_void_return',
    errorContains: '@SolidEffect cannot be applied to a non-void method',
  ),
  (
    name: 'm4_04_static',
    errorContains: '@SolidEffect cannot be applied to a static method',
  ),
  (
    name: 'm4_04_abstract',
    errorContains: '@SolidEffect cannot be applied to an abstract method',
  ),
  (
    name: 'm4_04_getter',
    errorContains: '@SolidEffect cannot be applied to a getter',
  ),
  (
    name: 'm4_04_setter',
    errorContains: '@SolidEffect cannot be applied to a setter',
  ),
  (
    name: 'm4_04_top_level',
    errorContains: '@SolidEffect cannot be applied to a top-level function',
  ),
  (
    name: 'm4_04_field',
    errorContains: '@SolidEffect cannot be applied to a field',
  ),
];

void main() {
  runRejectionCases('m4_04 invalid @SolidEffect targets', _cases);
}
