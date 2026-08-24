// Unit tests for the instance-field tier of `value_rewriter.dart`'s
// cross-class `.value` resolution (`_resolveInstanceFieldTypeNameFromAst`).
//
// The `testBuilder` golden harness (see `test/integration/golden_test.dart`)
// fully resolves plain-Dart receiver types even without this tier — a field
// of a non-Flutter type resolves via `Expression.staticType` regardless of
// whether the Flutter SDK is available in the sandbox (only Flutter-typed
// expressions resolve to `InvalidType` there; see `placement_visitor_test.
// dart`). So the golden pair `cross_class_instance_field_read` /
// `cross_class_instance_field_no_state` is real regression coverage but
// does not, by itself, prove the new AST fallback tier is what did the
// work. This suite calls `collectValueEdits` directly against `parseString`
// output — a genuinely UNRESOLVED AST (every `staticType` is null, mirroring
// the real fallback trigger: a `BuildStep.resolver` that hasn't fully
// resolved the receiver) — so a passing test can only be explained by the
// AST-only parameter/instance-field tiers.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/value_rewriter.dart';
import 'package:test/test.dart';

/// Parses [source] (no resolver — every `staticType` is null) and returns
/// the [MethodDeclaration] named [methodName] on the class named
/// [className].
MethodDeclaration _method(String source, String className, String methodName) {
  final unit = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration || decl.name.lexeme != className) continue;
    for (final member in decl.members) {
      if (member is MethodDeclaration && member.name.lexeme == methodName) {
        return member;
      }
    }
  }
  fail('method $className.$methodName not found');
}

void main() {
  group('cross-class instance-field resolution (unresolved AST)', () {
    const classRegistry = {
      'AuthRepository': {'session'},
    };

    test('guard-style null check gains .value', () {
      const source = '''
class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  bool hasSession() {
    return _authRepository.session != null;
  }
}
''';
      final method = _method(source, 'SessionGuard', 'hasSession');
      final result = collectValueEdits(
        method,
        const {},
        source,
        classRegistry: classRegistry,
      );

      final rewritten = applyEditsToRange(
        source.substring(method.offset, method.end),
        result.edits,
        method.offset,
      );
      expect(rewritten, contains('_authRepository.session.value != null'));
    });

    test('chained member access through ! gains .value before the bang', () {
      const source = '''
class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  int sessionLength() {
    return _authRepository.session!.length;
  }
}
''';
      final method = _method(source, 'SessionGuard', 'sessionLength');
      final result = collectValueEdits(
        method,
        const {},
        source,
        classRegistry: classRegistry,
      );

      final rewritten = applyEditsToRange(
        source.substring(method.offset, method.end),
        result.edits,
        method.offset,
      );
      expect(rewritten, contains('_authRepository.session.value!.length'));
    });

    test('.hasValue chain is not double-rewritten', () {
      const source = '''
class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  bool sessionResolved() {
    return _authRepository.session.hasValue;
  }
}
''';
      final method = _method(source, 'SessionGuard', 'sessionResolved');
      final result = collectValueEdits(
        method,
        const {},
        source,
        classRegistry: classRegistry,
      );

      final rewritten = applyEditsToRange(
        source.substring(method.offset, method.end),
        result.edits,
        method.offset,
      );
      expect(rewritten, contains('_authRepository.session.hasValue'));
      expect(rewritten, isNot(contains('.session.value.hasValue')));
    });

    test('explicit .value chain is not double-rewritten', () {
      const source = '''
class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  String? rawSession() {
    return _authRepository.session.value;
  }
}
''';
      final method = _method(source, 'SessionGuard', 'rawSession');
      final result = collectValueEdits(
        method,
        const {},
        source,
        classRegistry: classRegistry,
      );

      final rewritten = applyEditsToRange(
        source.substring(method.offset, method.end),
        result.edits,
        method.offset,
      );
      expect(rewritten, contains('_authRepository.session.value'));
      expect(rewritten, isNot(contains('.value.value')));
    });

    test(
      'field whose type is not in classRegistry is left untouched',
      () {
        const source = '''
class Reporter {
  Reporter(this._helper);

  final PlainHelper _helper;

  int report() {
    return _helper.count;
  }
}
''';
        final method = _method(source, 'Reporter', 'report');
        // `PlainHelper` never enters the registry (only classes with
        // `@SolidState` members do) — no edit should fire even though the
        // field's declared type resolves fine.
        final result = collectValueEdits(
          method,
          const {},
          source,
          classRegistry: classRegistry,
        );

        expect(result.edits, isEmpty);
      },
    );

    test(
      'field whose registered type does not own the accessed member is '
      'left untouched',
      () {
        const source = '''
class Reporter {
  Reporter(this._authRepository);

  final AuthRepository _authRepository;

  String other() {
    return _authRepository.other;
  }
}
''';
        final method = _method(source, 'Reporter', 'other');
        // `AuthRepository` IS registered, but `other` is not one of its
        // `@SolidState` members (only `session` is) — the field-name
        // discrimination inside `_maybeRewriteCrossClass` must still gate
        // the rewrite.
        final result = collectValueEdits(
          method,
          const {},
          source,
          classRegistry: classRegistry,
        );

        expect(result.edits, isEmpty);
      },
    );

    test(
      'a same-named method parameter shadows the field and suppresses the '
      'rewrite',
      () {
        const source = '''
class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  bool hasSession(_authRepository) {
    return _authRepository.session != null;
  }
}
''';
        final method = _method(source, 'SessionGuard', 'hasSession');
        // The parameter `_authRepository` (untyped — resolves to `dynamic`
        // at runtime) shadows the field of the same name inside this
        // method body. Falling through to the field's declared type would
        // rewrite a receiver that, at runtime, is NOT an `AuthRepository`.
        final result = collectValueEdits(
          method,
          const {},
          source,
          classRegistry: classRegistry,
        );

        expect(result.edits, isEmpty);
      },
    );
  });
}
