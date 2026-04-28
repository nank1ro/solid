import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a plain Dart class (no widget supertype) containing `@SolidState`
/// fields by replacing each annotated field with a `Signal<T>(…)` and
/// synthesizing a fresh `dispose()` method.
///
/// See SPEC §8.3 and §10. The synthesized `dispose()` has neither `@override`
/// nor `super.dispose()` because the supertype chain is `Object` only.
///
/// Currently only classes whose every member is an `@SolidState`-annotated
/// field are supported. Any other member (existing `dispose()`, constructors,
/// non-annotated fields, methods, …) throws [CodeGenerationError] —
/// dispose-merge and in-place patching are scheduled for later milestones.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
///
/// [source] is unused here (full reconstruction from AST); it is part of the
/// signature so the dispatcher in `builder.dart` can pass it uniformly to
/// every class-kind rewriter.
RewriteResult rewritePlainClass(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
  List<EffectModel> solidEffects,
  String source,
) {
  final className = classDecl.name.lexeme;
  // M2-01 ships getter→Computed for `StatelessWidget` only; reject here so
  // M1-14's valid-target pass isn't silently undone.
  rejectIfGettersNotYetSupported(solidGetters, 'plain class', className);
  // M4-01 ships method→Effect for `StatelessWidget` only; M4-08 lifts this
  // guard for plain-class lowering. Reject here so the M4-04 valid-target
  // pass isn't silently undone.
  rejectIfEffectsNotYetSupported(solidEffects, 'plain class', className);
  _checkUnsupportedMembers(classDecl, solidFields, className);

  final signalFields = solidFields.map(emitSignalField).join('\n');
  final dispose = emitDispose(
    solidFields.map((f) => f.fieldName).toList(),
    inheritsDispose: false,
  );

  return (
    text:
        '''
class $className {
$signalFields

$dispose
}''',
    solidartNames: const <String>{'Signal'},
  );
}

/// Throws [CodeGenerationError] if [classDecl] contains any member other than
/// an `@SolidState` field. Surfacing these explicitly avoids silently dropping
/// user code while the rewriter is incomplete.
void _checkUnsupportedMembers(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  String className,
) {
  final annotatedNames = solidFields.map((f) => f.fieldName).toSet();
  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      final varName = member.fields.variables.first.name.lexeme;
      if (!annotatedNames.contains(varName)) {
        throw CodeGenerationError(
          'plain class with non-annotated field "$varName" is not yet '
          'supported',
          null,
          className,
        );
      }
      continue;
    }
    throw CodeGenerationError(
      'plain class with ${_memberKindLabel(member)} is not yet supported',
      null,
      className,
    );
  }
}

/// Human-readable label for an unsupported [ClassMember], used in error
/// messages. Avoids leaking the analyzer's `…Impl` runtime type names.
String _memberKindLabel(ClassMember member) {
  if (member is MethodDeclaration) {
    return member.name.lexeme == 'dispose'
        ? 'existing dispose() method'
        : 'method "${member.name.lexeme}"';
  }
  if (member is ConstructorDeclaration) return 'constructor';
  return 'member';
}
