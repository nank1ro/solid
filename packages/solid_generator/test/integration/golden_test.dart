// Integration suite for the Solid builder's paired-golden tests.
// New cases extend [goldenNames]; the body of this file does not change.

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
        if (await isMultiFileFixture(name)) {
          await _runMultiFileGolden(name);
          return;
        }
        await _runSingleFileGolden(name);
      });
    }
  });
}

Future<void> _runSingleFileGolden(String name) async {
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
}

Future<void> _runMultiFileGolden(String name) async {
  final inputs = await loadGoldenMultiInput(name);

  if (_updateGoldens) {
    final captured = await runMultiFileBuilderCapture(name, inputs);
    for (final entry in captured.entries) {
      final outPath =
          '${await goldenDir()}/outputs/$name/'
          '${entry.key.replaceFirst(RegExp(r'\.dart$'), '.g.dart')}';
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(entry.value);
    }
    return;
  }

  final expectedTexts = <String, String>{};
  for (final relativePath in inputs.keys) {
    final expectedPath =
        '${await goldenDir()}/outputs/$name/'
        '${relativePath.replaceFirst(RegExp(r'\.dart$'), '.g.dart')}';
    final expectedFile = File(expectedPath);
    if (!expectedFile.existsSync()) {
      fail(
        'missing expected fixture: $expectedPath\n'
        'Run UPDATE_GOLDENS=1 dart test to create it.',
      );
    }
    expectedTexts[relativePath] = expectedFile.readAsStringSync();
  }

  final inputAssets = <String, String>{
    for (final entry in inputs.entries)
      'a|source/$name/${entry.key}': entry.value,
  };
  final outputAssertions = <String, Object>{
    for (final entry in expectedTexts.entries)
      'a|lib/$name/${entry.key}': entry.value,
  };

  await testBuilder(
    solidBuilder(BuilderOptions.empty),
    inputAssets,
    outputs: outputAssertions,
  );
}
