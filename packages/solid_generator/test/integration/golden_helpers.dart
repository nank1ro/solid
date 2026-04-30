// Shared helpers for the integration suite. Not picked up by `dart test`
// directly (no `_test.dart` suffix) — imported by the *_test.dart files.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:solid_generator/builder.dart';
import 'package:test/test.dart';

/// Names of golden cases under `test/golden/{inputs,outputs}/`.
///
/// M1+ TODOs append case names here. Each entry `name` requires:
///   `test/golden/inputs/<name>.dart`   — hand-written source with @Solid* annotations
///   `test/golden/outputs/<name>.g.dart` — expected builder output
const List<String> goldenNames = <String>[
  'm1_01_int_field_with_initializer',
  'm1_02_late_string_no_initializer',
  'm1_03_nullable_int_field',
  'm1_04_custom_name_parameter',
  'm1_05_counter_stateless_full',
  'm1_06_plain_class_no_widget',
  'm1_07_existing_state_class',
  'm1_08_import_rewrite',
  'm1_12_passthrough_no_annotations',
  'm1_13_multiple_constructors',
  'm2_01_simple_computed_with_deps',
  'm2_01b_block_body_computed',
  'm2_03_computed_read_in_build',
  'm2_04_dispose_order',
  'm3_01_text_arg_gets_value',
  'm3_02_onpressed_untracked',
  'm3_03_value_key_tracked',
  'm3_05_type_aware_no_double_append',
  'm3_06_string_interpolation_bare',
  'm3_08_builder_closure_tracked',
  'm3_08b_block_body_builder_closure_tracked',
  'm3_09_shadowing',
  'm3_10_existing_signalbuilder',
  'm3_11_nested_tracked_reads',
  'm3_12_untracked_extension',
  'm4_01_simple_effect_with_deps',
  'm4_02_effect_with_signal_and_computed',
  'm4_03_effect_block_body_shadowing',
  'm4_08_effect_on_state_class',
  'm4_08_effect_on_plain_class',
  'm5_01_simple_query_with_future',
  'm5_02_simple_query_with_stream',
  'm5_03_query_with_signal_computed_effect',
  'm5_04_query_when_in_build',
  'm5_06_query_refresh_in_onpressed',
  'm5_08_query_on_state_class',
  'm5_09_query_on_plain_class',
  'm5_10_query_with_one_signal_dep',
  'm5_10_query_with_multi_signal_deps',
];

/// Memoized golden directory resolution. Resolved relative to the package
/// root via `Isolate.resolvePackageUri`, so it works regardless of CWD.
Future<String> goldenDir() => _goldenDir ??= _resolveGoldenDir();
Future<String>? _goldenDir;

Future<String> _resolveGoldenDir() async {
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:solid_generator/builder.dart'),
  );
  return Directory.fromUri(libUri!.resolve('../test/golden')).path;
}

/// Loads the input fixture for [name], failing the test with a clear message
/// if the fixture file is missing.
Future<String> loadGoldenInput(String name) async {
  final path = '${await goldenDir()}/inputs/$name.dart';
  final file = File(path);
  if (!file.existsSync()) fail('missing input fixture: $path');
  return file.readAsStringSync();
}

/// Runs the builder once on [input] keyed under `source/<name>.dart` and
/// returns the bytes written to `lib/<name>.dart`, decoded as UTF-8.
///
/// Fails the test if the builder produced no output.
Future<String> runBuilderCapture(String name, String input) async {
  String? captured;
  await testBuilder(
    solidBuilder(BuilderOptions.empty),
    {'a|source/$name.dart': input},
    outputs: {
      'a|lib/$name.dart': predicate<List<int>>((bytes) {
        captured = utf8.decode(bytes);
        return true;
      }),
    },
  );
  if (captured == null) fail('builder produced no output for $name');
  return captured!;
}

/// Registers one rejection test per entry in [cases] inside a `group` named
/// [groupName]. Each entry's `name` resolves to a fixture under
/// `test/golden/inputs/<name>.dart`; the assertion is that the builder fails
/// with exactly one error whose message contains `errorContains`.
///
/// `testBuilder` captures thrown exceptions into `result.errors`, so this
/// inspects that list rather than relying on `throwsA`.
void runRejectionCases(
  String groupName,
  List<({String name, String errorContains})> cases,
) {
  group(groupName, () {
    for (final c in cases) {
      test(c.name, () async {
        final input = await loadGoldenInput(c.name);
        final result = await testBuilder(
          solidBuilder(BuilderOptions.empty),
          {'a|source/${c.name}.dart': input},
        );
        expect(result.succeeded, isFalse);
        expect(result.errors, hasLength(1));
        expect(result.errors.single, contains(c.errorContains));
      });
    }
  });
}
