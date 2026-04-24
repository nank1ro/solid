import 'package:analyzer/dart/ast/ast.dart';

/// The four kinds of class that `@SolidState` can attach to.
///
/// See SPEC Section 8.
enum ClassKind {
  /// A `class Foo extends StatelessWidget` declaration.
  ///
  /// Transformed per SPEC Section 8.1 — the class is rewritten as a
  /// `StatefulWidget` + `State<X>` pair.
  statelessWidget,

  /// A `class Foo extends StatefulWidget` declaration.
  ///
  /// No direct transformation; the sibling `State<X>` subclass (if any) is
  /// the rewrite target per SPEC Section 8.2.
  statefulWidget,

  /// A `class _FooState extends State<Foo>` declaration.
  ///
  /// Transformed in-place per SPEC Section 8.2 (fix for issue #3).
  stateClass,

  /// Any other class (no widget supertype, or no `extends` clause at all).
  ///
  /// Transformed in-place per SPEC Section 8.3.
  plainClass,
}

/// Classifies [decl] based on the textual name of its `extends` clause.
///
/// Uses unresolved AST — the superclass is matched by lexeme only. This is
/// adequate for M1 because the only relevant supertypes are `StatelessWidget`,
/// `StatefulWidget`, and `State`, all of which are imported from
/// `package:flutter/widgets.dart` and are not shadowed in practice.
ClassKind classKindOf(ClassDeclaration decl) {
  final superName = decl.extendsClause?.superclass.name.lexeme;
  return switch (superName) {
    'StatelessWidget' => ClassKind.statelessWidget,
    'StatefulWidget' => ClassKind.statefulWidget,
    'State' => ClassKind.stateClass,
    _ => ClassKind.plainClass,
  };
}
