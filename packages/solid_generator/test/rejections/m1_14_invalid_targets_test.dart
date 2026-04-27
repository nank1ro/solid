// Rejection suite for M1-14: invalid `@SolidState` placements per SPEC §3.1.

import '../integration/golden_helpers.dart';

/// Each case pairs a fixture name with the SPEC phrase the resulting error
/// must contain.
const List<({String name, String errorContains})> _cases = [
  (
    name: 'm1_14_final_field',
    errorContains: '@SolidState cannot be applied to a final field',
  ),
  (
    name: 'm1_14_const_field',
    errorContains: '@SolidState cannot be applied to a const field',
  ),
  (
    name: 'm1_14_static_field',
    errorContains: '@SolidState cannot be applied to a static field',
  ),
  (
    name: 'm1_14_static_getter',
    errorContains: '@SolidState cannot be applied to a static getter',
  ),
  (
    name: 'm1_14_top_level',
    errorContains: '@SolidState cannot be applied to a top-level variable',
  ),
  (
    name: 'm1_14_top_level_getter',
    errorContains: '@SolidState cannot be applied to a top-level getter',
  ),
  (
    name: 'm1_14_method',
    errorContains: '@SolidState cannot be applied to a method',
  ),
  (
    name: 'm1_14_setter',
    errorContains: '@SolidState cannot be applied to a setter',
  ),
];

void main() {
  runRejectionCases('m1_14 invalid @SolidState targets', _cases);
}
