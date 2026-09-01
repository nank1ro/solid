// Resolved-`staticType`-tier coverage for two SignalBase-detection fixes
// that solid_generator's own `testBuilder` sandbox (`golden_test.dart`,
// `value_rewriter_test.dart`'s unresolved suite) cannot isolate, because
// both bugs live entirely inside the `resolved is InterfaceType` branch of
// their respective functions:
//
//  * `target_validator._isSignalBaseTyped` used to anchor its resolved-tier
//    `SignalBase` match to `packageName: 'flutter_solidart'`, but
//    `SignalBase`'s declaring library is always `package:solidart` (which
//    `flutter_solidart` only re-exports) — so in a REAL resolved build the
//    resolved tier could never match, silently letting
//    `@SolidEnvironment late Signal<int> x;` through unrejected. Fixed by
//    routing through `element_utils.isSolidartSignalType`, which checks
//    both package names.
//  * `value_rewriter._isSolidartSignalReceiver`'s shadow guard used to run
//    BEFORE the resolved-type check, and a local variable's own name is
//    always present in its own declaration scope — so `final alias =
//    bag.sig; alias.value` was always treated as "shadowed" and never
//    tracked as a reactive read, even though the resolved type proves
//    `alias` is a signal. Fixed by moving the resolved-type check first and
//    scoping the shadow guard to the lexeme-fallback tier only.
//
// `resolved/signal_detection_fixture.dart` is a real file on disk (not an
// inline string) so `resolveFile` resolves `package:flutter_solidart` for
// real, through the pub workspace's shared `package_config.json` — see that
// file's header comment for why a physical path is required.

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/target_validator.dart';
import 'package:solid_generator/src/transformation_error.dart';
import 'package:solid_generator/src/value_rewriter.dart';
import 'package:test/test.dart';

/// Resolved relative to the package root via `Isolate.resolvePackageUri` —
/// the same CWD-independent mechanism as `integration/golden_helpers.dart`.
/// CI invokes `dart test packages/solid_generator/` from the REPO ROOT, so a
/// `Directory.current`-relative path points at a file that does not exist,
/// and `resolveFile` answers with an EMPTY resolved unit rather than an
/// error — every assertion below would then pass or fail vacuously. Hence
/// the explicit existence check.
Future<String> _fixturePath() async {
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:solid_generator/builder.dart'),
  );
  final path = File.fromUri(
    libUri!.resolve('../test/resolved/signal_detection_fixture.dart'),
  ).path;
  if (!File(path).existsSync()) fail('missing resolved fixture: $path');
  return path;
}

/// The fixture's resolved unit, alongside its source text (taken from the
/// resolution result, so the two can never drift).
Future<({CompilationUnit unit, String source})> _resolvedFixture() async {
  final result = await resolveFile(path: await _fixturePath());
  if (result is! ResolvedUnitResult) {
    fail('fixture did not resolve as expected: $result');
  }
  return (unit: result.unit, source: result.content);
}

void main() {
  test(
    '@SolidEnvironment rejects a resolved Signal<T>-typed field '
    '(SignalBase declares in package:solidart, not flutter_solidart)',
    () async {
      final fixture = await _resolvedFixture();
      expect(
        () => validateSolidEnvironmentTargets(fixture.unit),
        throwsA(
          isA<ValidationError>().having(
            (e) => e.message,
            'message',
            contains(
              '@SolidEnvironment cannot be applied to a SignalBase-typed '
              'field',
            ),
          ),
        ),
      );
    },
  );

  test(
    'a local alias of a foreign signal is tracked even though its own name '
    'is in scope (resolved staticType tier runs before the shadow guard)',
    () async {
      final fixture = await _resolvedFixture();
      final result = collectValueEdits(
        _functionBody(fixture.unit, 'readAlias'),
        const {},
        fixture.source,
      );

      expect(
        result.trackedReadNamesByOffset,
        isNotEmpty,
        reason:
            '`alias.value` must be recorded as a tracked read; the shadow '
            'guard used to suppress it before the resolved type was ever '
            'consulted',
      );
    },
  );

  test(
    '`bag.sig.untracked.value` (Section 6.4 opt-out through a resolved '
    'generic extension chain) is never tracked',
    () async {
      final fixture = await _resolvedFixture();
      final result = collectValueEdits(
        _functionBody(fixture.unit, 'readOptOut'),
        const {},
        fixture.source,
      );

      expect(
        result.trackedReadNamesByOffset,
        isEmpty,
        reason:
            'the `.untracked` opt-out must suppress tracking even though '
            'the resolved receiver type is still the signal',
      );
    },
  );
}

/// The body of the top-level function named [name] in [unit].
FunctionBody _functionBody(CompilationUnit unit, String name) {
  for (final decl in unit.declarations) {
    if (decl is FunctionDeclaration && decl.name.lexeme == name) {
      return decl.functionExpression.body;
    }
  }
  fail('function $name not found in fixture');
}
