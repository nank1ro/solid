import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Compatibility accessors restoring the pre-analyzer-12 AST surface of
/// [ClassDeclaration] and [EnumDeclaration].
///
/// analyzer 12 reshaped class and enum declarations to support primary
/// constructors:
///
/// * the name identifier moved onto `namePart` (a [ClassNamePart] whose
///   `typeName` token holds the declared name), and
/// * the members and braces moved onto `body` (a [ClassBody]; the braces live
///   on its [BlockClassBody] subtype).
///
/// These shims re-expose the old getters with identical semantics so the
/// generator's call sites — and their offset-based source slicing — keep
/// working unchanged.
extension ClassDeclarationCompat on ClassDeclaration {
  /// The members declared in the class body (analyzer 12: `body.members`).
  NodeList<ClassMember> get members => body.members;

  /// The token for the class name (analyzer 12: `namePart.typeName`).
  Token get name => namePart.typeName;

  /// The opening brace of the class body (analyzer 12: on [BlockClassBody]).
  ///
  /// `body` is always a [BlockClassBody] here: Solid only processes
  /// brace-bodied declarations, while the brace-less `EmptyClassBody` arises
  /// only for augmentations, which Solid sources never contain. This mirrors
  /// the old non-null `ClassDeclaration.leftBracket` contract.
  Token get leftBracket => (body as BlockClassBody).leftBracket;

  /// The type parameters, if any (analyzer 12: `namePart.typeParameters`).
  TypeParameterList? get typeParameters => namePart.typeParameters;
}

/// Restores the pre-analyzer-12 `name` getter on [EnumDeclaration]; the token
/// now lives on `namePart.typeName`.
extension EnumDeclarationCompat on EnumDeclaration {
  /// The token for the enum name (analyzer 12: `namePart.typeName`).
  Token get name => namePart.typeName;
}
