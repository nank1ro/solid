import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields as a
/// `StatefulWidget` + `State<X>` pair. See SPEC §8.1 for the full
/// field-partition and constructor-preservation contract.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
RewriteResult rewriteStatelessWidget(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final reactiveFieldNames = solidFields.map((f) => f.fieldName).toSet();

  final members = _splitMembers(classDecl);
  final widgetBoundNames = _collectWidgetBoundNames(members.ctors);
  final partition = _partitionFields(
    members.fields,
    reactiveFieldNames,
    widgetBoundNames,
    source,
  );
  final ctorsBlock = _emitCtors(members.ctors, source);
  final buildMethodText = rewriteBuildMethod(
    members.buildMethod,
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

/// Single-pass classification of [classDecl]'s members into the three buckets
/// the rewriter cares about: every `ConstructorDeclaration`, every
/// `FieldDeclaration`, and the (required) `build` method. Throws
/// [AnalysisError] if no `build` method is present — not a valid
/// `StatelessWidget` per SPEC §8.1.
({
  List<ConstructorDeclaration> ctors,
  List<FieldDeclaration> fields,
  MethodDeclaration buildMethod,
})
_splitMembers(ClassDeclaration classDecl) {
  final ctors = <ConstructorDeclaration>[];
  final fields = <FieldDeclaration>[];
  MethodDeclaration? buildMethod;
  for (final member in classDecl.members) {
    if (member is ConstructorDeclaration) {
      ctors.add(member);
    } else if (member is FieldDeclaration) {
      fields.add(member);
    } else if (member is MethodDeclaration && member.name.lexeme == 'build') {
      buildMethod = member;
    }
  }
  if (buildMethod == null) {
    throw AnalysisError(
      'StatelessWidget has no build() method to preserve',
      null,
      classDecl.name.lexeme,
    );
  }
  return (ctors: ctors, fields: fields, buildMethod: buildMethod);
}

/// Union of field names bound by any **generative** constructor in [ctors] —
/// either as a `this.X` formal parameter or as the LHS of an init-list field
/// assignment. Factory constructors are skipped: their body returns an
/// instance via redirection or a regular method call and never binds a field
/// directly to a parameter. (`ConstructorDeclaration` exposes only
/// `factoryKeyword` in the public analyzer API; there is no `isFactory`
/// getter, hence the null-check.)
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

typedef _FieldPartition = ({String widgetFieldsText, String stateFieldsText});

/// Returns the verbatim source text of every non-`@SolidState` field in
/// [fields], partitioned into widget-bound (per [widgetBoundNames]) and
/// state-bound. Each block is 2-space indented and trimmed; either may be
/// empty.
_FieldPartition _partitionFields(
  List<FieldDeclaration> fields,
  Set<String> solidFieldNames,
  Set<String> widgetBoundNames,
  String source,
) {
  final widgetBuf = StringBuffer();
  final stateBuf = StringBuffer();
  for (final field in fields) {
    final firstName = field.fields.variables.first.name.lexeme;
    if (solidFieldNames.contains(firstName)) continue;
    final memberText = source.substring(field.offset, field.end);
    if (widgetBoundNames.contains(firstName)) {
      widgetBuf.writeln('  $memberText');
    } else {
      stateBuf.writeln('  $memberText');
    }
  }
  return (
    widgetFieldsText: widgetBuf.toString().trimRight(),
    stateFieldsText: stateBuf.toString().trimRight(),
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
