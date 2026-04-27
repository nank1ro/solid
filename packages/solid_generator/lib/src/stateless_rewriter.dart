import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields and/or
/// `@SolidState` getters as a `StatefulWidget` + `State<X>` pair. See SPEC
/// §8.1 for the full field-partition and constructor-preservation contract;
/// SPEC §4.5 for the getter→`Computed` lowering.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
RewriteResult rewriteStatelessWidget(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final reactiveNames = <String>{
    ...solidFields.map((f) => f.fieldName),
    ...solidGetters.map((g) => g.getterName),
  };

  final members = _splitMembers(classDecl);
  final widgetBoundNames = _collectWidgetBoundNames(members.ctors);
  final partition = _partitionFields(
    members.fields,
    reactiveNames,
    widgetBoundNames,
    source,
  );
  final ctorsBlock = _emitCtors(members.ctors, source);
  final buildMethodText = rewriteBuildMethod(
    members.buildMethod,
    reactiveNames,
    source,
  );

  final reactiveBlock = _emitReactiveBlock(
    classDecl,
    solidFields,
    solidGetters,
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
    reactiveBlock.fieldsText,
    reactiveBlock.disposeNamesInDeclarationOrder,
    partition.stateFieldsText,
    buildMethodText,
  );

  final solidartNames = <String>{'Signal', 'SignalBuilder'};
  if (solidGetters.isNotEmpty) solidartNames.add('Computed');

  return (
    text: '$widgetClass\n\n$stateClass\n',
    solidartNames: solidartNames,
  );
}

/// Returns the source-ordered emission of every reactive declaration on
/// [classDecl] (Signal field + Computed getter) as a single 2-space-indented
/// block, plus the declaration-order list of dispose names that pairs with
/// it. Source order — not field-then-getter — is the contract a `Computed`
/// depends on: it must reference fields declared before it, so the emitted
/// `late final` Computed must appear after the `Signal`s it reads in the
/// rewritten State class.
({String fieldsText, List<String> disposeNamesInDeclarationOrder})
_emitReactiveBlock(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
) {
  final fieldByName = {for (final f in solidFields) f.fieldName: f};
  final getterByName = {for (final g in solidGetters) g.getterName: g};
  final lines = <String>[];
  final disposeNames = <String>[];

  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      final name = member.fields.variables.first.name.lexeme;
      final f = fieldByName[name];
      if (f != null) {
        lines.add(emitSignalField(f));
        disposeNames.add(f.fieldName);
      }
      continue;
    }
    if (member is MethodDeclaration && member.isGetter) {
      final name = member.name.lexeme;
      final g = getterByName[name];
      if (g != null) {
        lines.add(emitComputedField(g));
        disposeNames.add(g.getterName);
      }
    }
  }

  return (
    fieldsText: lines.join('\n'),
    disposeNamesInDeclarationOrder: disposeNames,
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
/// the synthesized reactive fields so original declaration order is preserved.
/// [reactiveFieldsText] is the source-ordered emission of every reactive
/// declaration (Signal field + Computed getter) on the original class.
String _emitStateClass(
  String className,
  String stateClassName,
  String reactiveFieldsText,
  List<String> disposeNamesInDeclarationOrder,
  String stateFieldsText,
  String buildMethodText,
) {
  final dispose = emitDispose(
    disposeNamesInDeclarationOrder,
    inheritsDispose: true,
  );
  final fieldsPrefix = stateFieldsText.isNotEmpty ? '$stateFieldsText\n\n' : '';

  return '''
class $stateClassName extends State<$className> {
$fieldsPrefix$reactiveFieldsText

$dispose

  $buildMethodText
}''';
}
