import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites an existing `State<X>` subclass containing `@SolidState` fields
/// **in place** — without splitting the class. Replaces every `@SolidState`
/// field with a `Signal<T>(…)` declaration, routes `build()` through the
/// reactive-read pipeline, and merges reactive disposals into any existing
/// `dispose()` body.
///
/// See SPEC §8.2 and §10. This is the fix for issue #3 — a `StatefulWidget`
/// whose `State<X>` subclass declared `@SolidState` fields was silently passed
/// through unchanged in v1.
///
/// Member ordering and non-annotated members (other fields, `initState`,
/// `didUpdateWidget`, user methods, constructors, …) are emitted verbatim
/// from [source] so that lifecycle bodies round-trip byte-identical.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
RewriteResult rewriteStateClass(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
  String source,
) {
  final className = classDecl.name.lexeme;
  // M2-01 ships getter→Computed for `StatelessWidget` only. The in-place
  // merge logic this rewriter is built around does not yet handle the
  // `late final ... = Computed<T>(...)` slot; reject so M1-14's valid-target
  // pass isn't silently undone here.
  rejectIfGettersNotYetSupported(
    solidGetters,
    'existing State<X> subclass',
    className,
  );
  // Index annotated fields by name for O(1) lookup during the member walk.
  // The builder already parsed `@SolidState` once when computing [solidFields];
  // re-parsing here would double the annotation-reader cost per file.
  final modelByName = {for (final f in solidFields) f.fieldName: f};
  final reactiveNames = modelByName.keys.toSet();
  final disposeNames = solidFields.map((f) => f.fieldName).toList();
  final pieces = <String>[];
  var sawDispose = false;

  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      final varName = member.fields.variables.first.name.lexeme;
      final model = modelByName[varName];
      if (model != null) {
        pieces.add(emitSignalField(model));
      } else {
        pieces.add(source.substring(member.offset, member.end));
      }
      continue;
    }
    if (member is MethodDeclaration) {
      final name = member.name.lexeme;
      if (name == 'build') {
        pieces.add(rewriteBuildMethod(member, reactiveNames, source));
      } else if (name == 'dispose') {
        pieces.add(_mergeDispose(member, disposeNames, source, className));
        sawDispose = true;
      } else {
        pieces.add(source.substring(member.offset, member.end));
      }
      continue;
    }
    pieces.add(source.substring(member.offset, member.end));
  }

  if (!sawDispose) {
    pieces.add(emitDispose(disposeNames, inheritsDispose: true));
  }

  final header = source.substring(
    classDecl.offset,
    classDecl.leftBracket.offset,
  );
  return (
    text: '$header{\n${pieces.join('\n\n')}\n}',
    solidartNames: const <String>{'Signal'},
  );
}

/// Prepends one `<name>.dispose();` call per reactive declaration to the
/// existing `dispose()` body's leading boundary, leaving the rest of the body
/// untouched (SPEC §10).
///
/// [disposeNamesInDeclarationOrder] is the unified, source-ordered list of
/// reactive declarations (Signal field + Computed getter). Reverse-iterating
/// it puts dependents ahead of their dependencies in the dispose body.
///
/// Throws [CodeGenerationError] if the existing `dispose()` uses an
/// expression body (`=> …`) — the merge is only well-defined for a block.
String _mergeDispose(
  MethodDeclaration method,
  List<String> disposeNamesInDeclarationOrder,
  String source,
  String className,
) {
  final body = method.body;
  if (body is! BlockFunctionBody) {
    throw CodeGenerationError(
      'existing dispose() must have a block body for reactive merge',
      null,
      className,
    );
  }
  final lbrace = body.block.leftBracket.offset;
  // The original source after `{` already begins with `\n` (the body's first
  // line break) on every reasonable formatting; prepending `\n<disposals>`
  // yields a single blank-line-free splice, leaving the rest of the body
  // byte-identical to the source. The `DartFormatter` pass normalises any
  // residual whitespace.
  final disposals = disposeNamesInDeclarationOrder.reversed
      .map((name) => '    $name.dispose();')
      .join('\n');
  return '${source.substring(method.offset, lbrace + 1)}'
      '\n$disposals'
      '${source.substring(lbrace + 1, method.end)}';
}
