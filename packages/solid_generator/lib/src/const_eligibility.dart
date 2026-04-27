import 'package:analyzer/dart/ast/ast.dart';

/// Returns `true` when [classDecl]'s non-`@SolidState` fields are all
/// `const`-eligible: every such field is declared `final` and every variable's
/// initializer (when present) is a compile-time constant expression.
///
/// Used by the stateless rewriter (SPEC §8.1, §14 item 7) to decide whether
/// to emit `const` on the public `StatefulWidget` constructor. `@SolidState`
/// fields are excluded because they move off the widget class entirely (onto
/// the synthesized `State<X>` subclass).
///
/// A class with zero non-`@SolidState` fields is vacuously eligible — every
/// existing M1 golden (m1_01..m1_12) hits this branch and continues to emit
/// `const`.
///
/// The predicate runs over the unresolved AST produced by `parseString`, so
/// it is a conservative *syntactic* whitelist (see [_isCompileTimeConst]).
/// A false negative merely omits `const` (safe — user can add it manually);
/// a false positive would emit a broken `const` (unsafe — never accept
/// anything ambiguous).
bool isConstEligible(
  ClassDeclaration classDecl,
  Set<String> solidStateFieldNames,
) {
  for (final member in classDecl.members) {
    if (member is! FieldDeclaration) continue;
    // `@SolidState` is enforced single-variable by SPEC §3.1, so checking
    // the first variable's name is sufficient to skip it.
    final firstName = member.fields.variables.first.name.lexeme;
    if (solidStateFieldNames.contains(firstName)) continue;

    if (!member.fields.isFinal) return false;
    for (final variable in member.fields.variables) {
      final init = variable.initializer;
      if (init != null && !_isCompileTimeConst(init)) return false;
    }
  }
  return true;
}

/// Conservative syntactic whitelist for compile-time-constant expressions.
///
/// Recognized as const:
/// - numeric / boolean / null / string / symbol literals (single string
///   literals only — interpolations are rejected because the interpolation
///   itself is a runtime concatenation)
/// - `AdjacentStrings` (`'foo' 'bar'`) when every part is const
/// - `InstanceCreationExpression` with the `const` keyword present — the
///   `const` keyword's textual presence is dispositive on unresolved AST
/// - `ListLiteral` / `SetOrMapLiteral` with the `const` keyword present
/// - `ParenthesizedExpression` whose inner expression is const
/// - `PrefixExpression` with `-` or `!` whose operand is const
///
/// Everything else (including `StringInterpolation`, bare identifiers,
/// non-`const` constructor calls, conditional expressions, type casts) is
/// rejected.
bool _isCompileTimeConst(Expression expr) {
  if (expr is IntegerLiteral) return true;
  if (expr is DoubleLiteral) return true;
  if (expr is BooleanLiteral) return true;
  if (expr is NullLiteral) return true;
  if (expr is SimpleStringLiteral) return true;
  if (expr is SymbolLiteral) return true;
  if (expr is AdjacentStrings) {
    return expr.strings.every(_isCompileTimeConst);
  }
  if (expr is InstanceCreationExpression) {
    return expr.isConst;
  }
  if (expr is ListLiteral) {
    return expr.isConst;
  }
  if (expr is SetOrMapLiteral) {
    return expr.isConst;
  }
  if (expr is ParenthesizedExpression) {
    return _isCompileTimeConst(expr.expression);
  }
  if (expr is PrefixExpression) {
    final op = expr.operator.lexeme;
    return (op == '-' || op == '!') && _isCompileTimeConst(expr.operand);
  }
  return false;
}
