import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a plain Dart class (no widget supertype) containing `@SolidState`
/// fields and/or `@SolidEffect` methods by replacing each annotated field
/// with a `Signal<T>(…)`, each annotated method with a `late final … =
/// Effect(…)`, and synthesizing a fresh `dispose()` method (plus, when
/// Effects exist, a fresh no-arg constructor whose body materializes them
/// — the plain-class analogue of the State class's `initState()`
/// materialization, SPEC §4.7).
///
/// See SPEC §8.3 (plain class lowering) and §10 (dispose contract). The
/// synthesized `dispose()` has neither `@override` nor `super.dispose()`
/// because the supertype chain is `Object` only.
///
/// Currently only classes whose every member is an `@SolidState`-annotated
/// field or `@SolidEffect`-annotated method are supported. Any other member
/// (existing `dispose()`, user-defined constructors, non-annotated fields,
/// non-Effect methods, …) throws [CodeGenerationError] — dispose-merge,
/// constructor-merge, and in-place patching are scheduled for later
/// milestones.
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
  // Source-ordered emission so Signal fields and Effect fields interleave by
  // declaration order — required by SPEC §10's reverse-disposal rule (an
  // Effect must be declared after the Signals it reads, so reverse order
  // disposes the Effect before its dependencies).
  final fieldByName = {for (final f in solidFields) f.fieldName: f};
  final effectByName = {for (final e in solidEffects) e.methodName: e};
  _checkUnsupportedMembers(classDecl, fieldByName, effectByName, className);

  final pieces = <String>[];
  final disposeNames = <String>[];
  final effectNames = <String>[];

  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      // Non-annotated fields are rejected by `_checkUnsupportedMembers`
      // above, so the lookup always hits.
      final f = fieldByName[member.fields.variables.first.name.lexeme]!;
      pieces.add(emitSignalField(f));
      disposeNames.add(f.fieldName);
      continue;
    }
    if (member is MethodDeclaration) {
      // Non-Effect methods are rejected by `_checkUnsupportedMembers`
      // above, so the lookup always hits.
      final e = effectByName[member.name.lexeme]!;
      pieces.add(emitEffectField(e));
      disposeNames.add(e.methodName);
      effectNames.add(e.methodName);
    }
  }

  final fields = pieces.join('\n');
  // No-arg constructor only when Effects need materialization — keeps the
  // Signal-only output byte-identical to the M1-06 plain-class golden,
  // which has no synthesized constructor.
  final ctor = effectNames.isEmpty
      ? ''
      : '\n\n${emitConstructor(className, effectNames)}';
  final dispose = emitDispose(disposeNames, inheritsDispose: false);

  return (
    text: 'class $className {\n$fields$ctor\n\n$dispose\n}',
    solidartNames: <String>{
      'Signal',
      if (effectNames.isNotEmpty) 'Effect',
    },
  );
}

/// Throws [CodeGenerationError] if [classDecl] contains any member other than
/// an `@SolidState`-annotated field (key in [fieldByName]) or an
/// `@SolidEffect`-annotated method (key in [effectByName]). Surfacing these
/// explicitly avoids silently dropping user code while the rewriter is
/// incomplete.
void _checkUnsupportedMembers(
  ClassDeclaration classDecl,
  Map<String, FieldModel> fieldByName,
  Map<String, EffectModel> effectByName,
  String className,
) {
  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      final varName = member.fields.variables.first.name.lexeme;
      if (!fieldByName.containsKey(varName)) {
        throw CodeGenerationError(
          'plain class with non-annotated field "$varName" is not yet '
          'supported',
          null,
          className,
        );
      }
      continue;
    }
    if (member is MethodDeclaration &&
        effectByName.containsKey(member.name.lexeme)) {
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
