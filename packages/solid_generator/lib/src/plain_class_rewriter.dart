import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a plain Dart class (no widget supertype) containing `@SolidState`
/// fields by replacing each annotated field with a `Signal<T>(…)` and
/// synthesizing a fresh `dispose()` method.
///
/// See SPEC §8.3 and §10. The synthesized `dispose()` has neither `@override`
/// nor `super.dispose()` because the supertype chain is `Object` only.
///
/// **M1-06 scope.** This rewriter only handles classes whose every member is
/// an `@SolidState`-annotated field. The following deferred cases throw
/// [CodeGenerationError] rather than silently dropping data:
///
/// - Existing user-declared `dispose()` method (SPEC §10 merge algorithm) —
///   scheduled for a later M1 TODO.
/// - Any non-annotated field, constructor, method, or other member —
///   scheduled for a later M1 TODO that introduces in-place SourceEdit
///   patching (analogous to M1-07's `State<X>` approach).
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
///
/// The [source] parameter is unused today (full reconstruction) but is kept
/// for signature parity with the other class-kind rewriters.
String rewritePlainClass(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  String source,
) {
  final className = classDecl.name.lexeme;
  _checkUnsupportedMembers(classDecl, solidFields, className);

  final signalFields = solidFields.map(emitSignalField).join('\n');
  final dispose = emitDispose(
    solidFields,
    emitOverride: false,
    emitSuperCall: false,
  );

  return '''
class $className {
$signalFields

$dispose
}''';
}

/// Throws [CodeGenerationError] if the class contains any member that is not
/// an `@SolidState` field. Deferred cases are surfaced explicitly rather than
/// silently dropped so the developer learns the case is unsupported.
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
          'plain class with non-annotated field "$varName" is not supported '
          'in M1-06 (scheduled for a later M1 TODO that introduces in-place '
          'patching)',
          null,
          className,
        );
      }
    } else if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
      throw CodeGenerationError(
        'plain class with existing dispose() method is not supported in '
        'M1-06 (scheduled for a later M1 TODO that adds dispose-merge '
        'support per SPEC §10)',
        null,
        className,
      );
    } else {
      throw CodeGenerationError(
        'plain class with member of kind ${member.runtimeType} is not '
        'supported in M1-06 (scheduled for a later M1 TODO that introduces '
        'in-place patching)',
        null,
        className,
      );
    }
  }
}
