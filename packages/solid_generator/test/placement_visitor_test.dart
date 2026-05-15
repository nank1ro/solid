// Unit tests for `placement_visitor.isWidgetTypedExpression`. The
// `testBuilder` golden harness can't exercise the B-2 strict path (no
// Flutter SDK in the sandbox; every Flutter expression resolves to
// `InvalidType`). This suite uses `resolveSource` to acquire a resolved
// LibraryElement for fixtures that use only `dart:core` types, where
// `staticType` IS populated, so the rejection branch is reachable.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:solid_generator/src/placement_visitor.dart';
import 'package:test/test.dart';

void main() {
  group('isWidgetTypedExpression', () {
    test('returns true when staticType is null (parsed-AST fallback)', () {
      // `parseString` produces an unresolved AST: every Expression's
      // `staticType` is null. The permissive fallback must allow these so
      // the unresolved code path doesn't lose its widget candidates.
      final parsed = parseString(
        content: '''
class _Foo {
  void m() {
    final s = 'hello'.toUpperCase();
  }
}
''',
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final invocations = _findMethodInvocations(parsed.unit);
      expect(invocations, isNotEmpty);
      for (final inv in invocations) {
        expect(inv.staticType, isNull);
        expect(isWidgetTypedExpression(inv), isTrue);
      }
    });

    test(
      'returns false when staticType is a non-Widget InterfaceType',
      () async {
        // `resolveSource` runs the analyzer with resolution. `'hello'.
        // toUpperCase()` returns `String` — a dart:core InterfaceType whose
        // supertype chain doesn't include `Widget`. The B-2 strict gate must
        // reject this.
        await resolveSource(
          '''
class _Foo {
  void m() {
    final s = 'hello'.toUpperCase();
  }
}
''',
          (resolver) async {
            final library = await resolver.libraryFor(
              AssetId('_resolve_source', 'lib/_resolve_source.dart'),
            );
            final node = await resolver.astNodeFor(
              library.firstFragment,
              resolve: true,
            );
            final unit = node! as CompilationUnit;
            final invocations = _findMethodInvocations(unit);
            expect(invocations, isNotEmpty);
            // `toUpperCase` is the call we care about — its staticType
            // should be `String`.
            final toUpperCase = invocations.firstWhere(
              (inv) => inv.methodName.name == 'toUpperCase',
            );
            final type = toUpperCase.staticType;
            expect(type, isNotNull);
            expect(type, isA<InterfaceType>());
            expect((type! as InterfaceType).element.name, 'String');
            expect(isWidgetTypedExpression(toUpperCase), isFalse);
          },
        );
      },
    );
  });
}

List<MethodInvocation> _findMethodInvocations(CompilationUnit unit) {
  final visitor = _MethodInvocationCollector();
  unit.accept(visitor);
  return visitor.invocations;
}

class _MethodInvocationCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = [];
  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }
}
