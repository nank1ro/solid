// Integration suite for the Solid builder's paired-golden tests.
// M1+ TODOs extend [goldenNames]; the body of this file does not change.

import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:solid_generator/builder.dart';
import 'package:test/test.dart';

import 'golden_helpers.dart';

final bool _updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

void main() {
  group('golden', () {
    for (final name in goldenNames) {
      test(name, () async {
        final input = await loadGoldenInput(name);
        final expectedPath = '${await goldenDir()}/outputs/$name.g.dart';
        final expectedFile = File(expectedPath);

        if (_updateGoldens) {
          final captured = await runBuilderCapture(name, input);
          expectedFile
            ..createSync(recursive: true)
            ..writeAsStringSync(captured);
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
