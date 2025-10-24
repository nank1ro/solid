import 'package:test/test.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import 'package:solid_generator/src/solid_builder.dart';

void main() {
  group('Transpiler Logic Tests', () {
    test('transforms @SolidState fields correctly', () async {
      const input = '''
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int count = 0;

  @SolidState(name: 'customCounter')
  int value = 5;
}
''';

      final builder = SolidBuilder();

      // Parse the input
      final parseResult = parseString(
        content: input,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      expect(parseResult.errors, isEmpty);

      // Transform using the internal method
      final result = await builder.transformAstForTesting(
        parseResult.unit,
        'test.dart',
        input,
      );

      // Verify transformations
      expect(result, contains('final count = Signal<int>(0, name: \'count\')'));
      expect(
        result,
        contains('final value = Signal<int>(5, name: \'customCounter\')'),
      );
      expect(
        result,
        contains('import \'package:flutter_solidart/flutter_solidart.dart\''),
      );

      // Ensure original annotations are removed
      expect(result, isNot(contains('@SolidState()')));
      expect(result, isNot(contains('int count = 0')));
    });

    test('copies files without reactive annotations unchanged', () async {
      const input = '''
class RegularClass {
  int normalField = 0;
  String get normalGetter => 'hello';
  void normalMethod() {
    print('hello');
  }
}
''';

      final builder = SolidBuilder();

      // Parse the input
      final parseResult = parseString(
        content: input,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      expect(parseResult.errors, isEmpty);

      // Transform using the internal method
      final result = await builder.transformAstForTesting(
        parseResult.unit,
        'test.dart',
        input,
      );

      // Should be identical (just with formatting)
      expect(result, contains('class RegularClass'));
      expect(result, contains('int normalField = 0'));
      expect(result, isNot(contains('Signal')));
      expect(
        result,
        isNot(
          contains('import \'package:flutter_solidart/flutter_solidart.dart\''),
        ),
      );
    });

    test('transforms @SolidState getters to Computed', () async {
      const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class Calculator {
  @SolidState()
  String get result => firstName + ' ' + lastName;
}
''';

      final builder = SolidBuilder();

      // Parse the input
      final parseResult = parseString(
        content: input,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      expect(parseResult.errors, isEmpty);

      // Transform using the internal method
      final result = await builder.transformAstForTesting(
        parseResult.unit,
        'test.dart',
        input,
      );

      // Verify transformation
      expect(result, contains('final result = Computed<String>'));
      expect(result, contains('firstName.value + \' \' + lastName.value'));
      expect(
        result,
        contains('import \'package:flutter_solidart/flutter_solidart.dart\''),
      );
    });

    test('transforms @SolidEffect methods to Effects', () async {
      const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class Logger {
  @SolidEffect()
  void logCounter() {
    print(counter);
  }
}
''';

      final builder = SolidBuilder();

      // Parse the input
      final parseResult = parseString(
        content: input,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      expect(parseResult.errors, isEmpty);

      // Transform using the internal method
      final result = await builder.transformAstForTesting(
        parseResult.unit,
        'test.dart',
        input,
      );

      // Verify transformation
      expect(result, contains('final logCounter = Effect'));
      expect(result, contains('print(counter.value)'));
      expect(
        result,
        contains('import \'package:flutter_solidart/flutter_solidart.dart\''),
      );
    });

    test('transforms @SolidQuery methods to Resources', () async {
      const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class DataService {
  @SolidQuery(name: 'userData', debounce: Duration(milliseconds: 300))
  Future<String> fetchUser() async {
    return 'user data';
  }
}
''';

      final builder = SolidBuilder();

      // Parse the input
      final parseResult = parseString(
        content: input,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      expect(parseResult.errors, isEmpty);

      // Transform using the internal method
      final result = await builder.transformAstForTesting(
        parseResult.unit,
        'test.dart',
        input,
      );

      // Verify transformation
      expect(result, contains('late final fetchUser = Resource<String>'));
      expect(result, contains('name: \'userData\''));
      expect(
        result,
        contains('debounceDelay: const Duration(milliseconds: 300)'),
      );
      expect(
        result,
        contains('import \'package:flutter_solidart/flutter_solidart.dart\''),
      );
    });

    test(
      'transforms @SolidQuery methods with multiple dependencies to Resource with Computed source',
      () async {
        const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class DataService {
  @SolidState()
  String? userId;

  @SolidState()
  String? authToken;

  @SolidQuery()
  Future<String> fetchData() async {
    if (userId == null || authToken == null) return 'no data';
    return 'user data';
  }
}
''';

        final builder = SolidBuilder();

        // Parse the input
        final parseResult = parseString(
          content: input,
          featureSet: FeatureSet.latestLanguageVersion(),
        );

        expect(parseResult.errors, isEmpty);

        // Transform using the internal method
        final result = await builder.transformAstForTesting(
          parseResult.unit,
          'test.dart',
          input,
        );

        // Verify transformation with multiple dependencies generates Computed source
        expect(result, contains('late final fetchData = Resource<String>'));
        expect(
          result,
          contains(
            'source: Computed(() => (userId.value, authToken.value), name: \'fetchDataSource\')',
          ),
        );
        expect(result, contains('name: \'fetchData\''));
        expect(
          result,
          contains('import \'package:flutter_solidart/flutter_solidart.dart\''),
        );
      },
    );
  });
}
