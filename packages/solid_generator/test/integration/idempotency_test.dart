// Idempotency suite: every golden runs through the builder twice and
// the two outputs must be byte-identical. Regression fence against
// accidental builder state — see plans/features/m1-solid-state-field.md
// Stage D and SPEC §5.4.

import 'package:test/test.dart';

import 'golden_helpers.dart';

void main() {
  group('idempotency', () {
    for (final name in goldenNames) {
      test('$name produces byte-identical output across two runs', () async {
        final input = await loadGoldenInput(name);

        final first = await runBuilderCapture(name, input);
        final second = await runBuilderCapture(name, input);

        expect(second, equals(first));
      });
    }
  });
}
