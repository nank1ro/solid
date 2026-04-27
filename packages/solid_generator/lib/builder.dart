import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/plain_class_rewriter.dart';
import 'package:solid_generator/src/reserved_annotation_validator.dart';
import 'package:solid_generator/src/state_class_rewriter.dart';
import 'package:solid_generator/src/stateless_rewriter.dart';
import 'package:solid_generator/src/target_validator.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Factory invoked by `build_runner` to create the Solid builder.
/// See SPEC Section 2.
Builder solidBuilder(BuilderOptions options) => _SolidBuilder();

/// Substring that must appear in any source file carrying a Solid annotation.
/// A file without this substring cannot possibly need transformation and is
/// skipped before `parseString` — the hot-path short-circuit for the typical
/// "no annotation" file (SPEC Section 2).
const String _solidAnnotationHint = '@Solid';

/// Shared formatter; `DartFormatter` construction allocates non-trivial
/// internal state, so hoisting out of `_renderOutput` avoids per-file cost.
final DartFormatter _formatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

class _SolidBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '^source/{{}}.dart': ['lib/{{}}.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    assert(
      buildStep.inputId.path.startsWith('source/'),
      'Input path must start with source/: ${buildStep.inputId.path}',
    );
    final outputId = AssetId(
      buildStep.inputId.package,
      buildStep.inputId.path.replaceFirst('source/', 'lib/'),
    );
    final source = await buildStep.readAsString(buildStep.inputId);

    // SPEC Section 2: files without any @Solid* annotation pass through
    // verbatim. A `source.contains` check is a cheap pre-parse guard — if the
    // marker is absent the file cannot need transformation.
    if (!source.contains(_solidAnnotationHint)) {
      await buildStep.writeAsString(outputId, source);
      return;
    }

    final parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    for (final diagnostic in parsed.errors) {
      log.warning(
        '${buildStep.inputId}: ${diagnostic.message} '
        '(offset ${diagnostic.offset})',
      );
    }

    // SPEC §3.2 + §13: reject reserved annotations (`@SolidEffect`,
    // `@SolidQuery`, `@SolidEnvironment`) before any other pass so the user
    // gets a fail-fast error instead of a silent passthrough.
    validateReservedAnnotations(parsed.unit);
    // SPEC §3.1 invalid-target guard. Must run before
    // `_collectAnnotatedClasses`; rejected targets (final / const / static
    // fields, setters, top-level vars, methods, …) never reach the readers.
    validateSolidStateTargets(parsed.unit);

    final annotatedClasses = _collectAnnotatedClasses(parsed.unit, source);
    if (annotatedClasses.every((c) => c.fields.isEmpty && c.getters.isEmpty)) {
      // Hint matched, but no `@SolidState` field or getter resolved — the
      // file likely contains a comment or string literal mentioning `@Solid…`.
      // Reserved annotations are caught upstream.
      await buildStep.writeAsString(outputId, source);
      return;
    }

    final transformed = _renderOutput(parsed.unit, annotatedClasses, source);
    await buildStep.writeAsString(outputId, transformed);
  }
}

/// One class declaration paired with the `@SolidState` fields and getters it
/// contains.
///
/// Both lists are empty when the class exists in the source but has no
/// `@SolidState` annotations; such classes are passed through verbatim.
class _AnnotatedClass {
  _AnnotatedClass(this.decl, this.fields, this.getters);
  final ClassDeclaration decl;
  final List<FieldModel> fields;
  final List<GetterModel> getters;
}

/// Walks [unit] once and returns every class paired with its `@SolidState`
/// fields and getters. Replaces an earlier double-walk (presence check +
/// collection) with a single traversal per file.
///
/// Fields are read first so the getter body's reactive-name set already
/// contains every field of the same class; a getter referencing a sibling
/// `@SolidState` field gets its `.value` rewrite applied per SPEC §5.1.
/// Getters then enter the name set in source order so a later getter can
/// also reference an earlier annotated getter.
List<_AnnotatedClass> _collectAnnotatedClasses(
  CompilationUnit unit,
  String source,
) {
  final result = <_AnnotatedClass>[];
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final fields = <FieldModel>[];
    final getters = <GetterModel>[];
    final reactiveNames = <String>{};
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        final model = readSolidStateField(member, source);
        if (model != null) {
          fields.add(model);
          reactiveNames.add(model.fieldName);
        }
        continue;
      }
      if (member is MethodDeclaration) {
        final model = readSolidStateGetter(member, reactiveNames, source);
        if (model != null) {
          getters.add(model);
          reactiveNames.add(model.getterName);
        }
      }
    }
    result.add(_AnnotatedClass(decl, fields, getters));
  }
  return result;
}

/// Renders the full `lib/` output for a file that has at least one annotated
/// class. Preserves non-annotated classes verbatim and rewrites annotated
/// ones per their class kind.
///
/// `flutter_solidart` is added to the import block iff any rewriter emitted
/// a Section 9 identifier (SPEC §9).
String _renderOutput(
  CompilationUnit unit,
  List<_AnnotatedClass> annotatedClasses,
  String source,
) {
  final results = annotatedClasses.map((c) {
    if (c.fields.isEmpty && c.getters.isEmpty) {
      return (
        text: source.substring(c.decl.offset, c.decl.end),
        solidartNames: const <String>{},
      );
    }
    return _rewriteClass(c.decl, c.fields, c.getters, source);
  }).toList();

  final imports = computeOutputImports(
    unit.directives.whereType<ImportDirective>().map(_importUri).toList(),
    addSolidart: results.any(
      (r) => r.solidartNames.any(solidartNames.contains),
    ),
  );
  final importBlock = imports.map((u) => "import '$u';").join('\n');

  final combined =
      '$importBlock\n\n${results.map((r) => r.text).join('\n\n')}\n';
  return _formatter.format(combined);
}

/// Dispatches on [decl]'s class kind to the matching rewriter.
RewriteResult _rewriteClass(
  ClassDeclaration decl,
  List<FieldModel> fields,
  List<GetterModel> getters,
  String source,
) {
  final kind = classKindOf(decl);
  switch (kind) {
    case ClassKind.statelessWidget:
      return rewriteStatelessWidget(decl, fields, getters, source);
    case ClassKind.plainClass:
      return rewritePlainClass(decl, fields, getters, source);
    case ClassKind.stateClass:
      return rewriteStateClass(decl, fields, getters, source);
    case ClassKind.statefulWidget:
      throw CodeGenerationError(
        'class-kind $kind is not supported yet '
        '(scheduled for a later M1 TODO)',
        null,
        decl.name.lexeme,
      );
  }
}

/// Returns the URI string of an `import '…';` directive, or the empty string
/// if the directive has no URI (should not happen for well-formed source).
String _importUri(ImportDirective d) => d.uri.stringValue ?? '';
