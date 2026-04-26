// Idempotency suite: every golden runs through the builder twice and
// the two outputs must be byte-identical. Regression fence against
// accidental builder state — see plans/features/m1-solid-state-field.md
// Stage D and SPEC §5.4.

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:solid_generator/builder.dart';
import 'package:test/test.dart';

import 'golden_test.dart' show goldenNames, resolveGoldenDir;

void main() {
  group('idempotency', () {
    for (final name in goldenNames) {
      test('$name produces byte-identical output across two runs', () async {
        final goldenDir = await resolveGoldenDir();
        final input = File('$goldenDir/inputs/$name.dart').readAsStringSync();

        final first = await _runBuilder(name, input);
        final second = await _runBuilder(name, input);

        expect(second, equals(first));
      });
    }
  });
}

Future<String> _runBuilder(String name, String input) async {
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
