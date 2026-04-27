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
