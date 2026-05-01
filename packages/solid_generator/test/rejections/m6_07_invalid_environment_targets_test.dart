// Rejection suite for M6-07: invalid `@SolidEnvironment` placements per
// SPEC §3.6.
//
// Cases ordered to mirror the SPEC §3.6 invalid-target enumeration and the
// validator's own check order in `_validateEnvironmentField`:
//   field with initializer → non-late field → final field → static field →
//   method → getter → setter → top-level variable → SignalBase-typed field →
//   plain-class host.
//
// The plain-class case is the only one whose rejection comes from
// `plain_class_rewriter.dart` (`CodeGenerationError`) rather than
// `target_validator.dart` (`ValidationError`); all others share the
// `@SolidEnvironment cannot be applied to a <kind>` message shape.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'm6_07_field_with_initializer',
    errorContains:
        '@SolidEnvironment cannot be applied to a field with initializer',
  ),
  (
    name: 'm6_07_field_without_late',
    errorContains: '@SolidEnvironment cannot be applied to a non-late field',
  ),
  (
    name: 'm6_07_final_field',
    errorContains: '@SolidEnvironment cannot be applied to a final field',
  ),
  (
    name: 'm6_07_static_field',
    errorContains: '@SolidEnvironment cannot be applied to a static field',
  ),
  (
    name: 'm6_07_method',
    errorContains: '@SolidEnvironment cannot be applied to a method',
  ),
  (
    name: 'm6_07_getter',
    errorContains: '@SolidEnvironment cannot be applied to a getter',
  ),
  (
    name: 'm6_07_setter',
    errorContains: '@SolidEnvironment cannot be applied to a setter',
  ),
  (
    name: 'm6_07_top_level',
    errorContains:
        '@SolidEnvironment cannot be applied to a top-level variable',
  ),
  (
    name: 'm6_07_signalbase_typed',
    errorContains:
        '@SolidEnvironment cannot be applied to a SignalBase-typed field',
  ),
  (
    name: 'm6_07_plain_class',
    errorContains: '@SolidEnvironment on plain class is invalid',
  ),
];

void main() {
  runRejectionCases('m6_07 invalid @SolidEnvironment targets', _cases);
}
