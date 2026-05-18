import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/element_utils.dart';

/// The four kinds of class that `@SolidState` can attach to.
enum ClassKind {
  /// A `class Foo extends StatelessWidget` declaration.
  ///
  /// The class is rewritten as a `StatefulWidget` + `State<X>` pair.
  statelessWidget,

  /// A `class Foo extends StatefulWidget` declaration.
  ///
  /// No direct transformation; the sibling `State<X>` subclass (if any) is
  /// the rewrite target.
  statefulWidget,

  /// A `class _FooState extends State<Foo>` declaration.
  ///
  /// Transformed in-place (fix for issue #3).
  stateClass,

  /// Any other class (no widget supertype, or no `extends` clause at all).
  ///
  /// Transformed in-place.
  plainClass,
}

/// Classifies [decl] by walking its resolved supertype chain, with a textual
/// fallback for the `extends` clause's lexeme.
///
/// Two-tier matching:
///
///  1. **Element-based.** When `decl.declaredFragment?.element` is populated,
///     walk `allSupertypes` and match by class name plus
///     `package:flutter/` library URI. This catches aliased Flutter imports
///     (`import '…' as fw; class X extends fw.StatelessWidget {}`).
///  2. **Textual fallback.** When the resolver hasn't run (parsed-AST
///     fallback, or test sandboxes without the Flutter SDK), the
///     `extends` clause's lexeme is matched. The relevant supertype names
///     (`StatelessWidget`, `StatefulWidget`, `State`) are not shadowed
///     in practice, so the textual match remains correct.
ClassKind classKindOf(ClassDeclaration decl) {
  final byElement = _classKindFromElement(decl);
  if (byElement != null) return byElement;
  final superName = decl.extendsClause?.superclass.name.lexeme;
  return switch (superName) {
    'StatelessWidget' => ClassKind.statelessWidget,
    'StatefulWidget' => ClassKind.statefulWidget,
    'State' => ClassKind.stateClass,
    _ => ClassKind.plainClass,
  };
}

/// Element-based classification of [decl]'s supertypes. Returns the matching
/// kind when one of `StatelessWidget` / `StatefulWidget` / `State` is found
/// in the resolved supertype chain (anchored to a `package:flutter/` library
/// URI); returns `null` when the AST is unresolved (no fragment / no element)
/// or when no Flutter widget supertype is present (which yields
/// [ClassKind.plainClass] via the textual fallback).
ClassKind? _classKindFromElement(ClassDeclaration decl) {
  final element = decl.declaredFragment?.element;
  if (element == null) return null;
  for (final supertype in element.allSupertypes) {
    final supertypeElement = supertype.element;
    if (!isFromPackage(supertypeElement.library.uri, 'flutter')) continue;
    switch (supertypeElement.name) {
      case 'StatelessWidget':
        return ClassKind.statelessWidget;
      case 'StatefulWidget':
        return ClassKind.statefulWidget;
      case 'State':
        return ClassKind.stateClass;
    }
  }
  return null;
}
