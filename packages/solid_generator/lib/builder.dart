import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/stateless_rewriter.dart';

/// Factory invoked by `build_runner` to create the Solid builder.
/// See SPEC Section 2.
Builder solidBuilder(BuilderOptions options) => _SolidBuilder();

/// Name prefix every Solid annotation shares (e.g. `SolidState`,
/// `SolidEffect`). Used to decide whether a file is transformed or copied
/// verbatim — see SPEC Section 2 ("Transformation vs verbatim copy").
const String _solidAnnotationPrefix = 'Solid';

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

    final parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final unit = parsed.unit;

    if (!_hasSolidAnnotation(unit)) {
      // SPEC Section 2: files without @Solid* annotations are copied verbatim.
      await buildStep.writeAsString(outputId, source);
      return;
    }

    final transformed = _transform(source, unit);
    await buildStep.writeAsString(outputId, transformed);
  }
}

/// Whether [unit] contains at least one `@Solid*` annotation on a field.
bool _hasSolidAnnotation(CompilationUnit unit) {
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    for (final member in decl.members) {
      if (member is! FieldDeclaration) continue;
      for (final ann in member.metadata) {
        if (ann.name.name.startsWith(_solidAnnotationPrefix)) return true;
      }
    }
  }
  return false;
}

/// Runs the transform pipeline for a file that has at least one `@Solid*`
/// annotation. Returns a fully-formatted Dart source string ready to write.
String _transform(String source, CompilationUnit unit) {
  final rewrittenClasses = <String>[];
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final fields = _collectSolidFields(decl, source);
    if (fields.isEmpty) {
      rewrittenClasses.add(source.substring(decl.offset, decl.end));
      continue;
    }
    rewrittenClasses.add(_rewriteClass(decl, fields, source));
  }

  final imports = computeOutputImports(
    unit.directives.whereType<ImportDirective>().map(_importUri).toList(),
    addSolidart: true,
  );
  final importBlock = imports.map((u) => "import '$u';").join('\n');

  final combined = '$importBlock\n\n${rewrittenClasses.join('\n\n')}\n';
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(combined);
}

/// Returns every `@SolidState`-annotated field declared inside [decl].
List<FieldModel> _collectSolidFields(ClassDeclaration decl, String source) {
  final fields = <FieldModel>[];
  for (final member in decl.members) {
    if (member is! FieldDeclaration) continue;
    final model = readSolidStateField(member, source);
    if (model != null) fields.add(model);
  }
  return fields;
}

/// Dispatches on [decl]'s class kind and emits the rewritten form.
String _rewriteClass(
  ClassDeclaration decl,
  List<FieldModel> fields,
  String source,
) {
  final kind = classKindOf(decl);
  switch (kind) {
    case ClassKind.statelessWidget:
      return rewriteStatelessWidget(decl, fields, source);
    case ClassKind.statefulWidget:
    case ClassKind.stateClass:
    case ClassKind.plainClass:
      throw UnimplementedError(
        '${decl.name.lexeme}: class-kind $kind is not supported in M1-01 '
        '(scheduled for a later M1 TODO).',
      );
  }
}

/// Returns the URI string of an `import '…';` directive, or the empty string
/// if the directive has no URI (should not happen for well-formed source).
String _importUri(ImportDirective d) => d.uri.stringValue ?? '';
