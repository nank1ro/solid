import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields as a
/// `StatefulWidget` + `State<X>` pair.
///
/// See SPEC Section 8.1. The emitted string is syntactically valid Dart but
/// is not guaranteed to be pretty-printed — run through `DartFormatter` before
/// writing.
///
/// Field placement (SPEC §8.1):
///   - `@SolidState` fields → `Signal` declarations on the State class
///     (SPEC §4).
///   - Non-`@SolidState` fields whose name appears either as a `this.X`
///     parameter or as the LHS of an init-list field assignment on **any**
///     generative constructor → kept verbatim on the public widget class.
///   - All other non-`@SolidState` fields (inline-init, `late`, unbound) →
///     moved verbatim to the State class.
///
/// Constructor handling (SPEC §8.1):
///   - Every constructor on the original class — unnamed, named generative,
///     and factory — is preserved verbatim on the rewritten widget class.
///   - The generator does NOT add or remove `const`. SPEC §9 already
///     delegates lint-time fixes (unused-import removal) to `dart fix --apply`;
///     the same step adds `const` to constructors that are eligible after the
///     class split (the rewritten widget often becomes const-eligible because
///     the `@SolidState` mutable field has moved to the State class).
RewriteResult rewriteStatelessWidget(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final reactiveFieldNames = solidFields.map((f) => f.fieldName).toSet();

  final ctors = _collectCtors(classDecl);
  final widgetBoundNames = _collectWidgetBoundNames(ctors);
  final partition = _partitionNonSolidFields(
    classDecl,
    reactiveFieldNames,
    widgetBoundNames,
    source,
  );
  final ctorsBlock = _emitCtors(ctors, source);

  final buildMethod = _findBuildMethod(classDecl);
  final buildMethodText = rewriteBuildMethod(
    buildMethod,
    reactiveFieldNames,
    source,
  );

  final widgetClass = _emitWidgetClass(
    className,
    stateClassName,
    ctorsBlock,
    partition.widgetFieldsText,
  );
  final stateClass = _emitStateClass(
    className,
    stateClassName,
    solidFields,
    partition.stateFieldsText,
    buildMethodText,
  );

  return (
    text: '$widgetClass\n\n$stateClass\n',
    solidartNames: const <String>{'Signal', 'SignalBuilder'},
  );
}

/// Returns every `ConstructorDeclaration` (unnamed, named, factory) on
/// [classDecl] in declaration order.
List<ConstructorDeclaration> _collectCtors(ClassDeclaration classDecl) {
  return [
    for (final member in classDecl.members)
      if (member is ConstructorDeclaration) member,
  ];
}

/// Union of field names bound by any **generative** constructor in [ctors] —
/// either as a `this.X` formal parameter or as the LHS of an init-list field
/// assignment. Factory constructors are skipped: their body returns an
/// instance via redirection or a regular method call and never binds a field
/// directly to a parameter.
Set<String> _collectWidgetBoundNames(List<ConstructorDeclaration> ctors) {
  final names = <String>{};
  for (final ctor in ctors) {
    if (ctor.factoryKeyword != null) continue;
    for (final param in ctor.parameters.parameters) {
      final inner = param is DefaultFormalParameter ? param.parameter : param;
      if (inner is FieldFormalParameter) {
        names.add(inner.name.lexeme);
      }
    }
    for (final initializer in ctor.initializers) {
      if (initializer is ConstructorFieldInitializer) {
        names.add(initializer.fieldName.name);
      }
    }
  }
  return names;
}

/// Verbatim source text of every non-`@SolidState` field, partitioned into
/// (widget-bound, state-bound) by [_collectWidgetBoundNames]. Each block is
/// 2-space indented and trimmed; either may be empty.
class _FieldPartition {
  _FieldPartition(this.widgetFieldsText, this.stateFieldsText);
  final String widgetFieldsText;
  final String stateFieldsText;
}

_FieldPartition _partitionNonSolidFields(
  ClassDeclaration classDecl,
  Set<String> solidFieldNames,
  Set<String> widgetBoundNames,
  String source,
) {
  final widgetBuf = StringBuffer();
  final stateBuf = StringBuffer();
  for (final member in classDecl.members) {
    if (member is! FieldDeclaration) continue;
    final firstName = member.fields.variables.first.name.lexeme;
    if (solidFieldNames.contains(firstName)) continue;
    final memberText = source.substring(member.offset, member.end);
    if (widgetBoundNames.contains(firstName)) {
      widgetBuf.writeln('  $memberText');
    } else {
      stateBuf.writeln('  $memberText');
    }
  }
  return _FieldPartition(
    widgetBuf.toString().trimRight(),
    stateBuf.toString().trimRight(),
  );
}

/// Emits every constructor verbatim, 2-space indented and joined by blank
/// lines. Returns an empty string when [ctors] is empty (Dart synthesises
/// the implicit default constructor on the rewritten class).
String _emitCtors(List<ConstructorDeclaration> ctors, String source) {
  if (ctors.isEmpty) return '';
  return ctors
      .map((c) => '  ${source.substring(c.offset, c.end)}')
      .join('\n\n');
}

/// Returns the `build` method declaration so it can be handed to the
/// reactive-rewrite pipeline. Throws [AnalysisError] if the class has no
/// `build` method (not a valid `StatelessWidget` under SPEC Section 8.1).
MethodDeclaration _findBuildMethod(ClassDeclaration classDecl) {
  for (final member in classDecl.members) {
    if (member is MethodDeclaration && member.name.lexeme == 'build') {
      return member;
    }
  }
  throw AnalysisError(
    'StatelessWidget has no build() method to preserve',
    null,
    classDecl.name.lexeme,
  );
}

/// Emits the public `StatefulWidget` half of the class split (SPEC §8.1).
///
/// [ctorsBlock] is the verbatim original constructors (unnamed, named, and
/// factory) — possibly empty if the class had no explicit constructor and
/// relies on Dart's implicit default. [widgetFieldsText] is the verbatim
/// source of every widget-bound non-`@SolidState` field.
String _emitWidgetClass(
  String className,
  String stateClassName,
  String ctorsBlock,
  String widgetFieldsText,
) {
  final parts = <String>[];
  if (ctorsBlock.isNotEmpty) parts.add(ctorsBlock);
  if (widgetFieldsText.isNotEmpty) parts.add(widgetFieldsText);
  parts.add(
    '  @override\n'
    '  State<$className> createState() => $stateClassName();',
  );
  return 'class $className extends StatefulWidget {\n'
      '${parts.join('\n\n')}\n'
      '}';
}

/// Emits the private `State<X>` half of the class split (SPEC §8.1).
///
/// `State<T>` has `dispose()` in its supertype chain, so the synthesized
/// `dispose()` is `@override` and ends with `super.dispose();` (SPEC §10).
/// [stateFieldsText] is the verbatim source of every non-`@SolidState`
/// non-widget-bound field that has been moved off the widget; emitted before
/// the synthesized signal fields so original declaration order is preserved.
String _emitStateClass(
  String className,
  String stateClassName,
  List<FieldModel> fields,
  String stateFieldsText,
  String buildMethodText,
) {
  final signalFields = fields.map(emitSignalField).join('\n');
  final dispose = emitDispose(fields, inheritsDispose: true);
  final fieldsPrefix = stateFieldsText.isNotEmpty ? '$stateFieldsText\n\n' : '';

  return '''
class $stateClassName extends State<$className> {
$fieldsPrefix$signalFields

$dispose

  $buildMethodText
}''';
}
