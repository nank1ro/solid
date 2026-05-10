// Rejection suite for invalid `@SolidEffect` placements.

import '../integration/golden_helpers.dart';

/// Each case pairs a fixture name with the phrase the resulting error must
/// contain. Cases ordered to mirror the bullet list:
/// parameterized → non-void → static → abstract/external → getter → setter →
/// top-level function → field.
const List<({String name, String errorContains})> _cases = [
  (
    name: 'solid_effect_parameterized',
    errorContains: '@SolidEffect cannot be applied to a parameterized method',
  ),
  (
    name: 'non_void_return',
    errorContains: '@SolidEffect cannot be applied to a non-void method',
  ),
  (
    name: 'solid_effect_static',
    errorContains: '@SolidEffect cannot be applied to a static method',
  ),
  (
    name: 'solid_effect_abstract',
    errorContains: '@SolidEffect cannot be applied to an abstract method',
  ),
  (
    name: 'solid_effect_getter',
    errorContains: '@SolidEffect cannot be applied to a getter',
  ),
  (
    name: 'solid_effect_setter',
    errorContains: '@SolidEffect cannot be applied to a setter',
  ),
  (
    name: 'solid_effect_top_level',
    errorContains: '@SolidEffect cannot be applied to a top-level function',
  ),
  (
    name: 'solid_effect_field',
    errorContains: '@SolidEffect cannot be applied to a field',
  ),
];

void main() {
  runRejectionCases('invalid @SolidEffect targets', _cases);
}
