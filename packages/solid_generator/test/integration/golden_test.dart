// Integration suite for the Solid builder's paired-golden tests.
// M1+ TODOs extend [_goldenNames]; the body of this file does not change.

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
const List<String> _goldenNames = <String>[
  'm1_01_int_field_with_initializer',
  'm1_02_late_string_no_initializer',
  'm1_03_nullable_int_field',
  'm1_04_custom_name_parameter',
];

/// Resolves the golden directory relative to the package root, regardless of
/// where `dart test` is invoked from.
Future<String> _resolveGoldenDir() async {
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:solid_generator/builder.dart'),
  );
  return Directory.fromUri(libUri!.resolve('../test/golden')).path;
}

final bool _updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

void main() {
  group('golden', () {
    for (final name in _goldenNames) {
      test(name, () async {
        final goldenDir = await _resolveGoldenDir();
        final inputPath = '$goldenDir/inputs/$name.dart';
        final expectedPath = '$goldenDir/outputs/$name.g.dart';

        final inputFile = File(inputPath);
        final expectedFile = File(expectedPath);

        if (!inputFile.existsSync()) {
          fail('missing input fixture: $inputPath');
        }

        final input = inputFile.readAsStringSync();

        if (_updateGoldens) {
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
          expectedFile
            ..createSync(recursive: true)
            ..writeAsStringSync(captured!);
          return;
        }

        if (!expectedFile.existsSync()) {
          fail(
            'missing expected fixture: $expectedPath\n'
            'Run UPDATE_GOLDENS=1 dart test to create it.',
          );
        }

        final expected = expectedFile.readAsStringSync();

        await testBuilder(
          solidBuilder(BuilderOptions.empty),
          {'a|source/$name.dart': input},
          outputs: {'a|lib/$name.dart': expected},
        );
      });
    }
  });
}
