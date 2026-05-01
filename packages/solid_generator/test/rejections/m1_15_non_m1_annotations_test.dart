// Marker test for M1-15 / M6-01: every shipped `@Solid*` annotation passes
// `validateReservedAnnotations` without raising. If a future SPEC revision
// re-reserves an annotation, the corresponding case here must be moved.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:solid_generator/src/reserved_annotation_validator.dart';
import 'package:test/test.dart';

void main() {
  group('m1_15', () {
    test('shipped @Solid* annotations are not reserved', () {
      final unit = parseString(
        content: '''
class Counter {
  @SolidState() int n = 0;
  @SolidEffect() void log() {}
  @SolidQuery() Future<int> fetch() async => 0;
  @SolidEnvironment() late int injected;
}
''',
      ).unit;
      expect(() => validateReservedAnnotations(unit), returnsNormally);
    });
  });
}
