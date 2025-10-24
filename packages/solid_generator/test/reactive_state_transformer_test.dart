import 'package:test/test.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'package:solid_generator/src/reactive_state_transformer.dart';
import 'package:solid_generator/src/result.dart';
import 'package:solid_generator/src/transformation_error.dart';

void main() {
  group('SolidStateTransformer', () {
    late SolidStateTransformer transformer;

    setUp(() {
      transformer = SolidStateTransformer();
    });

    group('canTransform', () {
      test('returns true for field with @SolidState annotation', () {
        final code = '''
          class TestClass {
            @SolidState()
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        expect(transformer.canTransform(fieldDeclaration), isTrue);
      });

      test('returns false for field without @SolidState annotation', () {
        final code = '''
          class TestClass {
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        expect(transformer.canTransform(fieldDeclaration), isFalse);
      });

      test('returns false for field with different annotation', () {
        final code = '''
          class TestClass {
            @override
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        expect(transformer.canTransform(fieldDeclaration), isFalse);
      });
    });

    group('transform', () {
      test('transforms simple field to Signal declaration', () {
        final code = '''
          class TestClass {
            @SolidState()
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        final result = transformer.transform(fieldDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains('final counter = Signal<int>(0'));
          expect(generatedCode, contains("name: 'counter'"));
        }
      });

      test('transforms field with custom name', () {
        final code = '''
          class TestClass {
            @SolidState(name: 'customCounter')
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        final result = transformer.transform(fieldDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains("name: 'customCounter'"));
        }
      });

      test('transforms field with String type', () {
        final code = '''
          class TestClass {
            @SolidState()
            String name = 'test';
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        final result = transformer.transform(fieldDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains('final name = Signal<String>('));
          expect(generatedCode, contains("'test'"));
        }
      });

      test('transforms field with nullable type', () {
        final code = '''
          class TestClass {
            @SolidState()
            String? name;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        final result = transformer.transform(fieldDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains('final name = Signal<String?>(null'));
        }
      });

      test('returns failure for field without @SolidState annotation', () {
        final code = '''
          class TestClass {
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        final result = transformer.transform(fieldDeclaration);

        expect(result.isFailure, isTrue);
        if (result is Failure<String, TransformationError>) {
          expect(result.error, isA<AnnotationParseError>());
        }
      });
    });

    group('extractDependencies', () {
      test('returns empty list for fields (no dependencies)', () {
        final code = '''
          class TestClass {
            @SolidState()
            int counter = 0;
          }
        ''';

        final fieldDeclaration = _parseFieldDeclaration(code);
        final dependencies = transformer.extractDependencies(fieldDeclaration);

        expect(dependencies, isEmpty);
      });
    });
  });

  group('ComputedTransformer', () {
    late SolidComputedTransformer transformer;

    setUp(() {
      transformer = SolidComputedTransformer();
    });

    group('canTransform', () {
      test('returns true for getter with @SolidState annotation', () {
        final code = '''
          class TestClass {
            @SolidState()
            String get fullName => 'John Doe';
          }
        ''';

        final getterDeclaration = _parseGetterDeclaration(code);
        expect(transformer.canTransform(getterDeclaration), isTrue);
      });

      test(
        'returns false for method (not getter) with @SolidState annotation',
        () {
          final code = '''
          class TestClass {
            @SolidState()
            String fullName() => 'John Doe';
          }
        ''';

          final methodDeclaration = _parseMethodDeclaration(code);
          expect(transformer.canTransform(methodDeclaration), isFalse);
        },
      );

      test('returns false for getter without @SolidState annotation', () {
        final code = '''
          class TestClass {
            String get fullName => 'John Doe';
          }
        ''';

        final getterDeclaration = _parseGetterDeclaration(code);
        expect(transformer.canTransform(getterDeclaration), isFalse);
      });
    });

    group('transform', () {
      test('transforms getter to Computed declaration', () {
        final code = '''
          class TestClass {
            @SolidState()
            String get fullName => 'John Doe';
          }
        ''';

        final getterDeclaration = _parseGetterDeclaration(code);
        final result = transformer.transform(getterDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains('final fullName = Computed<String>'));
          expect(generatedCode, contains("'John Doe'"));
          expect(generatedCode, contains("name: 'fullName'"));
        }
      });

      test('transforms getter with custom name', () {
        final code = '''
          class TestClass {
            @SolidState(name: 'customName')
            String get fullName => 'John Doe';
          }
        ''';

        final getterDeclaration = _parseGetterDeclaration(code);
        final result = transformer.transform(getterDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains("name: 'customName'"));
        }
      });
    });

    group('extractDependencies', () {
      test('extracts dependencies from getter expression', () {
        final code = '''
          class TestClass {
            @SolidState()
            String get fullName => firstName + ' ' + lastName;
          }
        ''';

        final getterDeclaration = _parseGetterDeclaration(code);
        final dependencies = transformer.extractDependencies(getterDeclaration);

        // Note: This is a simplified test - the actual dependency extraction
        // uses simple pattern matching, not full AST analysis
        expect(dependencies, isNotEmpty);
      });
    });
  });

  group('EffectTransformer', () {
    late SolidEffectTransformer transformer;

    setUp(() {
      transformer = SolidEffectTransformer();
    });

    group('canTransform', () {
      test('returns true for method with @SolidEffect annotation', () {
        final code = '''
          class TestClass {
            @SolidEffect()
            void logCounter() {
              print(counter);
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        expect(transformer.canTransform(methodDeclaration), isTrue);
      });

      test('returns false for method without @SolidEffect annotation', () {
        final code = '''
          class TestClass {
            void logCounter() {
              print(counter);
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        expect(transformer.canTransform(methodDeclaration), isFalse);
      });
    });

    group('transform', () {
      test('transforms method to Effect declaration', () {
        final code = '''
          class TestClass {
            @SolidEffect()
            void logCounter() {
              print(counter);
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        final result = transformer.transform(methodDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains('final logCounter = Effect'));
          expect(generatedCode, contains('counter.value'));
        }
      });
    });
  });

  group('QueryTransformer', () {
    late SolidQueryTransformer transformer;

    setUp(() {
      transformer = SolidQueryTransformer();
    });

    group('canTransform', () {
      test('returns true for method with @SolidQuery annotation', () {
        final code = '''
          class TestClass {
            @SolidQuery()
            Future<String> fetchData() async {
              return 'data';
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        expect(transformer.canTransform(methodDeclaration), isTrue);
      });

      test('returns false for method without @SolidQuery annotation', () {
        final code = '''
          class TestClass {
            Future<String> fetchData() async {
              return 'data';
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        expect(transformer.canTransform(methodDeclaration), isFalse);
      });
    });

    group('transform', () {
      test('transforms async method to Resource declaration', () {
        final code = '''
          class TestClass {
            @SolidQuery()
            Future<String> fetchData() async {
              return 'data';
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        final result = transformer.transform(methodDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(
            generatedCode,
            contains('late final fetchData = Resource<String>'),
          );
          expect(generatedCode, contains('() async'));
          expect(generatedCode, contains("name: 'fetchData'"));
        }
      });

      test('transforms method with custom name and debounce', () {
        final code = '''
          class TestClass {
            @SolidQuery(name: 'customQuery', debounce: Duration(milliseconds: 500))
            Future<String> fetchData() async {
              return 'data';
            }
          }
        ''';

        final methodDeclaration = _parseMethodDeclaration(code);
        final result = transformer.transform(methodDeclaration);

        expect(result.isSuccess, isTrue);
        if (result is Success<String, TransformationError>) {
          final generatedCode = result.value;
          expect(generatedCode, contains("name: 'customQuery'"));
          expect(
            generatedCode,
            contains('debounceDelay: const Duration(milliseconds: 500)'),
          );
        }
      });
    });
  });
}

/// Helper function to parse a field declaration from code
FieldDeclaration _parseFieldDeclaration(String code) {
  final parseResult = parseString(
    content: code,
    featureSet: FeatureSet.latestLanguageVersion(),
  );

  final unit = parseResult.unit;
  final classDeclaration = unit.declarations.first as ClassDeclaration;
  return classDeclaration.members.first as FieldDeclaration;
}

/// Helper function to parse a getter declaration from code
MethodDeclaration _parseGetterDeclaration(String code) {
  final parseResult = parseString(
    content: code,
    featureSet: FeatureSet.latestLanguageVersion(),
  );

  final unit = parseResult.unit;
  final classDeclaration = unit.declarations.first as ClassDeclaration;
  return classDeclaration.members.first as MethodDeclaration;
}

/// Helper function to parse a method declaration from code
MethodDeclaration _parseMethodDeclaration(String code) {
  final parseResult = parseString(
    content: code,
    featureSet: FeatureSet.latestLanguageVersion(),
  );

  final unit = parseResult.unit;
  final classDeclaration = unit.declarations.first as ClassDeclaration;
  return classDeclaration.members.first as MethodDeclaration;
}
