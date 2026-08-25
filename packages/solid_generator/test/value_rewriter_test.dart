// Unit tests for the parameter-shadow guard in `value_rewriter.dart`'s
// cross-class `.value` resolution (`_isParameterName` /
// `_resolveReceiverTypeName`).
//
// Every other new behavior this receiver-resolution tier introduces — the
// guard-style null check, the `!`-chain, the `.hasValue` / explicit `.value`
// no-double-rewrite guards, the `this.<field>` shape, bare and `??=` writes,
// and the "registered class but non-reactive member" negative — is pinned as
// golden input/output pairs in `test/golden/{inputs,outputs}/
// cross_class_instance_field_read.dart` instead: the `testBuilder` harness
// resolves a constructor-injected field's declared type (`final
// AuthRepository _authRepository;`) via `Expression.staticType` regardless
// of Flutter SDK availability, so those goldens exercise real input→output
// behavior end-to-end.
//
// The parameter-shadow guard is the one piece that behavior can't reach that
// way. `_isParameterName` exists specifically to stop an UNTYPED parameter
// (no `NamedType` — e.g. `hasSession(_authRepository)`, which infers
// `dynamic`) from falling through to a same-named field's type. But under a
// real resolver, `dynamic` already isn't an `InterfaceType`, so a golden
// with an untyped parameter would prove nothing about this guard
// specifically — the same "no rewrite" outcome falls out of resolved-AST
// tier 1 whether or not `_isParameterName` exists. Only a genuinely
// UNRESOLVED AST (every `staticType` null, mirroring a `BuildStep.resolver`
// that hasn't fully resolved the receiver) isolates the guard: without it,
// an untyped parameter would incorrectly fall through to tier 3 and resolve
// via the shadowed field. This suite calls `collectValueEdits` directly
// against `parseString` output to construct that unresolved AST.

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
  group('cross-class parameter-shadow guard (unresolved AST)', () {
    const classRegistry = {
      'AuthRepository': {'session'},
    };

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

    test(
      'this.<field>.<reactiveField> still rewrites even when a same-named '
      'parameter is in scope — this. explicitly bypasses shadowing',
      () {
        const source = '''
class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  bool hasSession(_authRepository) {
    return this._authRepository.session != null;
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
        expect(
          rewritten,
          contains('this._authRepository.session.value != null'),
        );
      },
    );
  });
}
