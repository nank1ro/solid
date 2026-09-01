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

  group('managed-field no-double-append guard is not widened by the '
      'foreign-signal getter set', () {
    // The foreign-signal read path recognizes a wider getter set than the
    // managed-member guard (`state` / `hasPreviousValue` on top of `value` /
    // `hasValue` / `previousValue`) because there the receiver is PROVEN to
    // be a `SignalBase`. Sharing one set between the two regresses every
    // `@SolidState` field whose own payload type happens to declare a member
    // of that name: the guard would read `machine.state` as "already on the
    // signal API" and skip the `.value` append, emitting `machine.state`
    // against a `Signal<MyMachine>` — which does not compile, and drops the
    // reactive read. The foreign side is pinned by the `GateProbe` class in
    // `test/golden/inputs/foreign_signal_value_read.dart`.
    test(
      '.state / .hasPreviousValue on a @SolidState field of a user type '
      'still lower to .value.<member>',
      () {
        const source = r'''
class Screen {
  MyMachine machine;

  String describe() {
    return '${machine.state} ${machine.hasPreviousValue}';
  }
}
''';
        final method = _method(source, 'Screen', 'describe');
        final result = collectValueEdits(method, const {'machine'}, source);

        final rewritten = applyEditsToRange(
          source.substring(method.offset, method.end),
          result.edits,
          method.offset,
        );
        expect(rewritten, contains(r'${machine.value.state}'));
        expect(rewritten, contains(r'${machine.value.hasPreviousValue}'));
      },
    );
  });

  group('cross-class name-collision guard (unresolved AST) — issue #110', () {
    test(
      'a name builder.dart flagged ambiguous never rewrites through an '
      'AST-only receiver, even when a matching qualified origin exists',
      () {
        const source = '''
class Holder {
  Holder(this.repo);

  final AuthRepository repo;

  bool hasSession() {
    return repo.session != null;
  }
}
''';
        final method = _method(source, 'Holder', 'hasSession');
        // `classRegistry` is empty here on purpose — mirrors what
        // `builder.dart::_populateCrossFileTypes`'s finalize pass actually
        // does to a flagged name (strips the flat entry; see that
        // function's doc comment). `classRegistryOrigins` DOES carry a
        // real, matching entry — `session` is exactly the field this body
        // reads — so the only thing standing between this receiver and a
        // (wrong, unproven) rewrite is the tier-1-URI-match requirement.
        final result = collectValueEdits(
          method,
          const {},
          source,
          classRegistryOrigins: const {
            'AuthRepository': {
              'package:app/auth_repository.dart': {'session'},
            },
          },
          classRegistryShadowedNames: const {'AuthRepository'},
        );

        // `repo`'s type resolves via AST-only tier 2 (the parameter/field
        // NamedType text) since this is an unresolved AST — no
        // `Expression.staticType`, hence no library URI ever reaches
        // `_fieldsForCrossClassName`. Per issue #110's conservative-
        // fallback invariant, a FLAGGED name can only resolve through a
        // tier-1 URI match; an AST-only tier must refuse regardless of how
        // plausible the qualified entry looks. The golden harness cannot
        // exercise this: `testBuilder`'s resolver always supplies a real
        // `staticType` for a `final AuthRepository repo;` field, so tier 1
        // would answer for real and this specific guard would never be the
        // reason a golden passes or fails — same "golden can't reach it"
        // reasoning as this file's header comment.
        expect(result.edits, isEmpty);
      },
    );
  });
}
