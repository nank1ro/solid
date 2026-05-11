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
/// New cases append names here. Each entry `name` requires:
///   `test/golden/inputs/<name>.dart`   — hand-written source with @Solid* annotations
///   `test/golden/outputs/<name>.g.dart` — expected builder output
const List<String> goldenNames = <String>[
  'int_field_with_initializer',
  'late_string_no_initializer',
  'nullable_int_field',
  'custom_name_parameter',
  'counter_stateless_full',
  'plain_class_no_widget',
  'existing_state_class',
  'import_rewrite',
  'passthrough_no_annotations',
  'multiple_constructors',
  'simple_computed_with_deps',
  'block_body_computed',
  'computed_read_in_build',
  'dispose_order',
  'text_arg_gets_value',
  'onpressed_untracked',
  'value_key_tracked',
  'type_aware_no_double_append',
  'string_interpolation_bare',
  'builder_closure_tracked',
  'block_body_builder_closure_tracked',
  'shadowing',
  'existing_signalbuilder',
  'nested_tracked_reads',
  'untracked_extension',
  'simple_effect_with_deps',
  'effect_with_signal_and_computed',
  'effect_block_body_shadowing',
  'effect_on_state_class',
  'effect_on_plain_class',
  'simple_query_with_future',
  'simple_query_with_stream',
  'query_with_signal_computed_effect',
  'query_when_in_build',
  'query_refresh_in_onpressed',
  'query_on_state_class',
  'query_on_plain_class',
  'query_with_one_signal_dep',
  'query_with_multi_signal_deps',
  'query_with_one_query_dep',
  'query_with_query_and_signal_deps',
  'query_with_multi_query_deps',
  'query_untracked_call',
  'query_with_debounce',
  'query_with_use_refreshing_false',
  'query_with_debounce_and_use_refreshing_false',
  'implements_existing',
  'extends_with_implements',
  'already_disposable',
  'user_dispose_body',
  'user_dispose_no_override',
  'simple_environment',
  'cross_class_value_read',
  'environment_on_state_class',
  'multi_environment',
  'environment_extension_used',
  'const_ctor_super_key',
  'const_ctor_field_formal',
  'const_ctor_literal_initializer',
  'const_ctor_assert_preserved',
  'const_call_site_top_level',
  'top_level_function_preserved',
  'top_level_variable_preserved',
  'top_level_extension_preserved',
  'provider_auto_dispose_simple',
  'multi_provider_recurse',
  'environment_extension_auto_dispose',
  'dispose_already_present_skipped',
  'provider_no_at_solid_annotations',
  'provider_value_skipped',
  'list_signal_field',
  'set_signal_field',
  'map_signal_field',
  'list_signal_lazy_fallback',
  'list_signal_nullable_fallback',
  'cross_class_list_signal_read',
  'cross_file_environment_read',
  'computed_on_plain_class',
  'plain_class_user_ctor_basic',
  'plain_class_user_ctor_with_effect',
  'plain_class_named_ctor',
  'computed_reading_same_class_collection',
  'collection_mixin_breadth',
  'collection_cascade',
  'late_hasvalue_chain',
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

/// True when [name] resolves to a multi-file fixture directory at
/// `test/golden/inputs/<name>/`, vs the conventional single-file fixture at
/// `test/golden/inputs/<name>.dart`. Used by the golden harness to dispatch
/// between single-file and multi-file paths.
Future<bool> isMultiFileFixture(String name) async {
  final dirPath = '${await goldenDir()}/inputs/$name';
  return Directory(dirPath).existsSync();
}

/// Loads every `*.dart` file under `test/golden/inputs/<name>/` and returns
/// a map of `{relativePath → contents}`. Relative paths are anchored to the
/// fixture directory (e.g. `widget.dart`, `controllers/foo.dart`).
///
/// Used by the multi-file branch of the golden harness for fixtures that
/// span more than one source file — e.g. cross-file `@SolidEnvironment`
/// scenarios where the consumer's `late T x;` resolves to a class defined
/// in a sibling source file.
Future<Map<String, String>> loadGoldenMultiInput(String name) async {
  final dirPath = '${await goldenDir()}/inputs/$name';
  final dir = Directory(dirPath);
  if (!dir.existsSync()) fail('missing multi-file input dir: $dirPath');
  final result = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    final relativePath = entity.path.substring(dirPath.length + 1);
    result[relativePath] = entity.readAsStringSync();
  }
  return result;
}

/// Runs the builder once on the multi-file [inputs] map (relative paths
/// keyed to source text) under the fixture `<name>/` and returns a
/// `{relativePath → outputText}` map containing the lowered output for
/// each input.
///
/// Each input file is registered under `a|source/<name>/<relativePath>` and
/// each output is captured from `a|lib/<name>/<relativePath>`.
Future<Map<String, String>> runMultiFileBuilderCapture(
  String name,
  Map<String, String> inputs,
) async {
  final captured = <String, String>{};
  final inputAssets = <String, String>{
    for (final entry in inputs.entries)
      'a|source/$name/${entry.key}': entry.value,
  };
  final outputMatchers = <String, Object>{
    for (final entry in inputs.entries)
      'a|lib/$name/${entry.key}': predicate<List<int>>((bytes) {
        captured[entry.key] = utf8.decode(bytes);
        return true;
      }),
  };
  await testBuilder(
    solidBuilder(BuilderOptions.empty),
    inputAssets,
    outputs: outputMatchers,
  );
  if (captured.length != inputs.length) {
    fail(
      'builder produced ${captured.length} outputs for $name, '
      'expected ${inputs.length}',
    );
  }
  return captured;
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
