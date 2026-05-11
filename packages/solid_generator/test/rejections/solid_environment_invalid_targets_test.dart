// Rejection suite for invalid `@SolidEnvironment` placements.
//
// Cases ordered to mirror the invalid-target enumeration and the validator's
// own check order in `_validateEnvironmentField`:
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
    name: 'field_with_initializer',
    errorContains:
        '@SolidEnvironment cannot be applied to a field with initializer',
  ),
  (
    name: 'field_without_late',
    errorContains: '@SolidEnvironment cannot be applied to a non-late field',
  ),
  (
    name: 'solid_environment_final_field',
    errorContains: '@SolidEnvironment cannot be applied to a final field',
  ),
  (
    name: 'solid_environment_static_field',
    errorContains: '@SolidEnvironment cannot be applied to a static field',
  ),
  (
    name: 'solid_environment_method',
    errorContains: '@SolidEnvironment cannot be applied to a method',
  ),
  (
    name: 'solid_environment_getter',
    errorContains: '@SolidEnvironment cannot be applied to a getter',
  ),
  (
    name: 'solid_environment_setter',
    errorContains: '@SolidEnvironment cannot be applied to a setter',
  ),
  (
    name: 'solid_environment_top_level',
    errorContains:
        '@SolidEnvironment cannot be applied to a top-level variable',
  ),
  (
    name: 'signalbase_typed',
    errorContains:
        '@SolidEnvironment cannot be applied to a SignalBase-typed field',
  ),
  (
    name: 'environment_plain_class',
    errorContains: '@SolidEnvironment on plain class is invalid',
  ),
];

void main() {
  runRejectionCases('invalid @SolidEnvironment targets', _cases);
}
