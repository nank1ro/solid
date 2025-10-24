import 'package:test/test.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'package:solid_generator/src/reactive_state_transformer.dart';

void main() {
  test('AST visitor extracts user-defined variable names', () {
    final code = '''
      class TestClass {
        @SolidState()
        String get fullName => firstName + ' ' + lastName;
      }
    ''';

    final parseResult = parseString(
      content: code,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final unit = parseResult.unit;
    final classDeclaration = unit.declarations.first as ClassDeclaration;
    final getterDeclaration =
        classDeclaration.members.first as MethodDeclaration;

    final transformer = SolidComputedTransformer();
    final dependencies = transformer.extractDependencies(getterDeclaration);

    // Should find firstName and lastName (user-defined variables)
    expect(dependencies, contains('firstName'));
    expect(dependencies, contains('lastName'));

    // Should not find string literals
    expect(dependencies, isNot(contains(' ')));
  });

  test('AST visitor handles complex expressions with user variables', () {
    final code = '''
      class TestClass {
        @SolidState()
        String get calculation => myVariable * anotherVar + someField - customValue;
      }
    ''';

    final parseResult = parseString(
      content: code,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final unit = parseResult.unit;
    final classDeclaration = unit.declarations.first as ClassDeclaration;
    final getterDeclaration =
        classDeclaration.members.first as MethodDeclaration;

    final transformer = SolidComputedTransformer();
    final dependencies = transformer.extractDependencies(getterDeclaration);

    // Should find all user-defined variables
    expect(dependencies, contains('myVariable'));
    expect(dependencies, contains('anotherVar'));
    expect(dependencies, contains('someField'));
    expect(dependencies, contains('customValue'));
  });

  test('AST visitor excludes method calls and property access', () {
    final code = '''
      class TestClass {
        @SolidState()
        String get result => someVar + getMethod() + object.property;
      }
    ''';

    final parseResult = parseString(
      content: code,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final unit = parseResult.unit;
    final classDeclaration = unit.declarations.first as ClassDeclaration;
    final getterDeclaration =
        classDeclaration.members.first as MethodDeclaration;

    final transformer = SolidComputedTransformer();
    final dependencies = transformer.extractDependencies(getterDeclaration);

    // Should find the variable
    expect(dependencies, contains('someVar'));
    expect(dependencies, contains('object'));

    // Should NOT find method names or property names
    expect(dependencies, isNot(contains('getMethod')));
    expect(dependencies, isNot(contains('property')));
  });
}
