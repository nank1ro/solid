// Rejection suite for invalid `@SolidState` placements.

import '../integration/golden_helpers.dart';

/// Each case pairs a fixture name with the phrase the resulting error
/// must contain.
const List<({String name, String errorContains})> _cases = [
  (
    name: 'solid_state_final_field',
    errorContains: '@SolidState cannot be applied to a final field',
  ),
  (
    name: 'const_field',
    errorContains: '@SolidState cannot be applied to a const field',
  ),
  (
    name: 'solid_state_static_field',
    errorContains: '@SolidState cannot be applied to a static field',
  ),
  (
    name: 'static_getter',
    errorContains: '@SolidState cannot be applied to a static getter',
  ),
  (
    name: 'solid_state_top_level',
    errorContains: '@SolidState cannot be applied to a top-level variable',
  ),
  (
    name: 'top_level_getter',
    errorContains: '@SolidState cannot be applied to a top-level getter',
  ),
  (
    name: 'solid_state_method',
    errorContains: '@SolidState cannot be applied to a method',
  ),
  (
    name: 'solid_state_setter',
    errorContains: '@SolidState cannot be applied to a setter',
  ),
];

void main() {
  runRejectionCases('invalid @SolidState targets', _cases);
}
