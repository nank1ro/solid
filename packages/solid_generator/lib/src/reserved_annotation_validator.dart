import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Reserved annotation names from `package:solid_annotations` whose full
/// contract is deferred to a later SPEC revision (SPEC §3.2 + §13). Detecting
/// any use causes the build to fail before transformation. The map value is
/// the violation code stamped onto [ValidationError.violationType].
///
/// `SolidEffect` is no longer in this list as of M4-01: the annotation now
/// lowers to `Effect(() { … })` per SPEC §4.7. Only the still-deferred
/// `@SolidQuery` and `@SolidEnvironment` remain reserved; both ship in
/// later milestones before v2 release (SPEC §13).
const Map<String, String> _reservedAnnotations = {
  'SolidQuery': 'RESERVED_ANNOTATION_SOLID_QUERY',
  'SolidEnvironment': 'RESERVED_ANNOTATION_SOLID_ENVIRONMENT',
};

/// SPEC §3.2 + §13 build-time guard: reject any `@SolidQuery` or
/// `@SolidEnvironment` use with a clear error that names the annotation and
/// quotes the SPEC §3.2 phrase verbatim.
///
/// Runs before transformation so users learn at build time that they're
/// using a not-yet-implemented annotation, instead of debugging missing
/// reactivity from a silent passthrough.
void validateReservedAnnotations(CompilationUnit unit) {
  unit.accept(_ReservedAnnotationVisitor());
}

class _ReservedAnnotationVisitor extends RecursiveAstVisitor<void> {
  @override
  void visitAnnotation(Annotation node) {
    final name = node.name.name;
    final code = _reservedAnnotations[name];
    if (code != null) {
      throw ValidationError(
        '@$name is not yet implemented; '
        'scheduled for a later v2 milestone',
        _locationFor(node),
        code,
      );
    }
    super.visitAnnotation(node);
  }
}

/// Walks up [ann]'s parents to build a `ClassName.member` (or bare
/// `member` / `topLevelName`) location string in a single pass — when the
/// member declaration is found, the same walk continues upward to capture
/// the enclosing class name without restarting from the member node.
String? _locationFor(Annotation ann) {
  String? memberPart;
  // Explicit `AstNode?` because `Annotation.parent` is overridden to
  // non-nullable `AstNode` — `var` infers a non-nullable type that the
  // subsequent `p = p.parent` reassignment would not satisfy.
  AstNode? p = ann.parent;
  while (p != null) {
    if (memberPart == null) {
      if (p is FieldDeclaration) {
        memberPart = p.fields.variables.first.name.lexeme;
      } else if (p is MethodDeclaration) {
        memberPart = p.name.lexeme;
      } else if (p is FunctionDeclaration) {
        return p.name.lexeme;
      } else if (p is TopLevelVariableDeclaration) {
        return p.variables.variables.first.name.lexeme;
      } else if (p is ClassDeclaration) {
        return p.name.lexeme;
      }
    } else if (p is ClassDeclaration) {
      return '${p.name.lexeme}.$memberPart';
    }
    p = p.parent;
  }
  return memberPart;
}
