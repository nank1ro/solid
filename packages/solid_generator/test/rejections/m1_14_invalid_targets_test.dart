// Rejection suite for M1-14: invalid `@SolidState` placements per SPEC §3.1.
// `testBuilder` captures thrown exceptions into `result.errors`, so the
// assertions check that list rather than `throwsA(...)`.

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:solid_generator/builder.dart';
import 'package:test/test.dart';

import '../integration/golden_helpers.dart';

/// Each case pairs a fixture name with the SPEC phrase the resulting error
/// must contain. The phrase is the contains-substring used by the assertion.
const List<({String name, String specPhrase})> _cases = [
  (
    name: 'm1_14_final_field',
    specPhrase: '@SolidState cannot be applied to a final field',
  ),
  (
    name: 'm1_14_const_field',
    specPhrase: '@SolidState cannot be applied to a const field',
  ),
  (
    name: 'm1_14_static_field',
    specPhrase: '@SolidState cannot be applied to a static field',
  ),
  (
    name: 'm1_14_static_getter',
    specPhrase: '@SolidState cannot be applied to a static getter',
  ),
  (
    name: 'm1_14_top_level',
    specPhrase: '@SolidState cannot be applied to a top-level variable',
  ),
  (
    name: 'm1_14_top_level_getter',
    specPhrase: '@SolidState cannot be applied to a top-level getter',
  ),
  (
    name: 'm1_14_method',
    specPhrase: '@SolidState cannot be applied to a method',
  ),
  (
    name: 'm1_14_setter',
    specPhrase: '@SolidState cannot be applied to a setter',
  ),
];

void main() {
  group('m1_14 invalid @SolidState targets', () {
    for (final c in _cases) {
      test(c.name, () async {
        final input = await loadGoldenInput(c.name);
        final result = await testBuilder(
          solidBuilder(BuilderOptions.empty),
          {'a|source/${c.name}.dart': input},
        );
        expect(result.succeeded, isFalse);
        expect(result.errors, hasLength(1));
        expect(result.errors.single, contains(c.specPhrase));
      });
    }
  });
}
