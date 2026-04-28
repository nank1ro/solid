import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Validates every `@SolidState` annotation in [unit] against the SPEC
/// Section 3.1 valid-target list. Throws [ValidationError] on the first
/// invalid placement; returns silently when every annotation targets a
/// valid declaration (instance field or instance getter).
///
/// Runs before transformation so the pre-existing builder pipeline (which
/// only walks `FieldDeclaration`s in `_collectAnnotatedClasses`) cannot
/// silently drop a `@SolidState` placed on a method, setter, top-level
/// declaration, or static/final/const field.
void validateSolidStateTargets(CompilationUnit unit) {
  for (final decl in unit.declarations) {
    if (decl is ClassDeclaration) {
      final className = decl.name.lexeme;
      for (final member in decl.members) {
        if (member is FieldDeclaration) _validateField(member, className);
        if (member is MethodDeclaration) _validateMethod(member, className);
      }
    } else {
      _validateTopLevel(decl);
    }
  }
}

/// Throws a [ValidationError] for `@SolidState` on a [kind] of declaration.
/// The violation code is derived from [kind] so message and code never drift.
Never _reject(String kind, String location) {
  final code =
      'INVALID_TARGET_'
      '${kind.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_')}';
  throw ValidationError(
    '@SolidState cannot be applied to a $kind',
    location,
    code,
  );
}

/// Rejects `@SolidState` on a class field that is `const`, `final`, or
/// `static`. Instance non-final non-const non-static fields fall through
/// silently — they are the canonical SPEC 3.1 valid target.
void _validateField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidStateName, field.metadata) == null) return;
  final varList = field.fields;
  final fieldName = varList.variables.first.name.lexeme;
  final location = '$className.$fieldName';
  // Order matters: `static const` reports as "const field" — the const-ness
  // is the dominant violation per the M1-14 TODO parenthetical guidance.
  if (varList.isConst) _reject('const field', location);
  if (varList.isFinal) _reject('final field', location);
  if (field.isStatic) _reject('static field', location);
}

/// Rejects `@SolidState` on a setter, static getter, or non-accessor method.
/// Instance getters fall through — they are valid SPEC 3.1 targets and M2
/// will emit `Computed`.
void _validateMethod(MethodDeclaration method, String className) {
  if (findAnnotationByName(solidStateName, method.metadata) == null) return;
  final location = '$className.${method.name.lexeme}';
  if (method.isSetter) _reject('setter', location);
  if (method.isGetter && method.isStatic) _reject('static getter', location);
  if (!method.isGetter && !method.isSetter) _reject('method', location);
  // Instance getter — valid SPEC 3.1 target; M2 emits Computed.
}

/// Rejects `@SolidState` on top-level variables, getters, and any other
/// non-class declaration form (top-level setters and methods land here too,
/// reusing the SETTER / METHOD codes).
void _validateTopLevel(CompilationUnitMember decl) {
  if (decl is TopLevelVariableDeclaration &&
      findAnnotationByName(solidStateName, decl.metadata) != null) {
    _reject('top-level variable', decl.variables.variables.first.name.lexeme);
  }
  if (decl is FunctionDeclaration &&
      findAnnotationByName(solidStateName, decl.metadata) != null) {
    final name = decl.name.lexeme;
    if (decl.isGetter) _reject('top-level getter', name);
    if (decl.isSetter) _reject('setter', name);
    _reject('method', name);
  }
}
