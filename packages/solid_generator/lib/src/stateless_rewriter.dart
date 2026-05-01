import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields,
/// `@SolidState` getters, `@SolidEffect` methods, and/or `@SolidQuery`
/// methods as a `StatefulWidget` + `State<X>` pair. See SPEC §8.1 for the
/// full field-partition and constructor-preservation contract; SPEC §4.5 for
/// the getter→`Computed` lowering; SPEC §4.7 for the method→`Effect`
/// lowering; SPEC §4.8 for the method→`Resource` lowering.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
RewriteResult rewriteStatelessWidget(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
  List<EffectModel> solidEffects,
  List<QueryModel> solidQueries,
  List<EnvironmentModel> solidEnvironments,
  Map<String, Set<String>> classRegistry,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final reactiveNames = <String>{
    ...solidFields.map((f) => f.fieldName),
    ...solidGetters.map((g) => g.getterName),
  };
  // SPEC §4.8 rule 3: query call expressions in `build` are tracked reads.
  // Names are kept separate from `reactiveNames` so the `.value` rewrite
  // (SPEC §5.1) does not fire on `<queryName>` identifiers.
  final queryNames = solidQueries.isEmpty
      ? const <String>{}
      : {for (final q in solidQueries) q.methodName};
  // Superset of `reactiveNames` that also includes `@SolidEnvironment` field
  // names. These are the field names `_emitReactiveBlock` will emit itself,
  // so `_partitionFields` must skip them on the source-text walk to avoid
  // double-emitting them as widget/state-bound fields.
  final partitionExcludeNames = <String>{
    ...reactiveNames,
    ...solidEnvironments.map((e) => e.fieldName),
  };

  final members = _splitMembers(classDecl);
  final widgetBoundNames = _collectWidgetBoundNames(members.ctors);
  final partition = _partitionFields(
    members.fields,
    partitionExcludeNames,
    widgetBoundNames,
    source,
  );
  final ctorsBlock = _emitCtors(members.ctors, source);
  final buildMethodText = rewriteBuildMethod(
    members.buildMethod,
    reactiveNames,
    source,
    queryNames: queryNames,
    classRegistry: classRegistry,
  );

  final reactiveBlock = _emitReactiveBlock(
    classDecl,
    solidFields,
    solidGetters,
    solidEffects,
    solidQueries,
    solidEnvironments,
  );

  final widgetClass = _emitWidgetClass(
    className,
    stateClassName,
    ctorsBlock,
    partition.widgetFieldsText,
  );
  final stateClass = _emitStateClass(
    className: className,
    stateClassName: stateClassName,
    reactiveFieldsText: reactiveBlock.fieldsText,
    disposeNamesInDeclarationOrder:
        reactiveBlock.disposeNamesInDeclarationOrder,
    effectNamesInDeclarationOrder: reactiveBlock.effectNamesInDeclarationOrder,
    stateFieldsText: partition.stateFieldsText,
    buildMethodText: buildMethodText,
  );

  // SPEC §9 import-add gates. `Signal` and `SignalBuilder` are only emitted
  // when there's a same-class reactive declaration to wrap. An env-only
  // class (M6-03 simple-environment) has no Signal/SignalBuilder reference
  // in its lowered output and so does NOT pull in `flutter_solidart`.
  final hasReactive =
      solidFields.isNotEmpty ||
      solidGetters.isNotEmpty ||
      solidQueries.isNotEmpty;
  final solidartNames = <String>{
    if (solidFields.isNotEmpty) 'Signal',
    if (hasReactive) 'SignalBuilder',
  };
  if (solidGetters.isNotEmpty) solidartNames.add('Computed');
  if (solidEffects.isNotEmpty) solidartNames.add('Effect');
  if (solidQueries.isNotEmpty) solidartNames.add('Resource');
  // A multi-dep query synthesizes a Record-Computed source field regardless
  // of whether the class has any `@SolidState` getter — so `Computed` may be
  // needed even when `solidGetters` is empty.
  if (solidQueries.any((q) => q.needsSourceComputed)) {
    solidartNames.add('Computed');
  }

  return (
    text: '$widgetClass\n\n$stateClass\n',
    solidartNames: solidartNames,
  );
}

/// Returns the source-ordered emission of every reactive declaration on
/// [classDecl] (Signal field + Computed getter + Effect method + Resource
/// query + `@SolidEnvironment` env field) as a single 2-space-indented block,
/// plus the declaration-order list of dispose names that pairs with it.
/// Source order is the contract that `Computed`, `Effect`, and the M5-10
/// query-source-Computed depend on: each must reference declarations defined
/// before it, so the emitted `late final` lines must appear after the
/// declarations they read in the rewritten State class.
///
/// `effectNamesInDeclarationOrder` is the Effect-only subset of
/// `disposeNamesInDeclarationOrder`, pulled out so the rewriter can
/// synthesize `initState()` that materializes each `late final` Effect field
/// at mount time (SPEC §4.7). Queries are intentionally NOT in this list —
/// per SPEC §4.8 rule 10 / §14 item 4, Resources are lazy and the late-final
/// initializer fires on first call-site read, never via `initState`.
///
/// `@SolidEnvironment` env fields (M6-03) are emitted in source-declaration
/// order alongside Signal/Computed/Effect/Resource fields but are NEVER added
/// to `disposeNames` (SPEC §10 — env fields are not host-disposed) and NEVER
/// added to `effectNames` (SPEC §4.9 rule 2 — env fields are lazy and need
/// no initState materialization).
({
  String fieldsText,
  List<String> disposeNamesInDeclarationOrder,
  List<String> effectNamesInDeclarationOrder,
})
_emitReactiveBlock(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
  List<EffectModel> solidEffects,
  List<QueryModel> solidQueries,
  List<EnvironmentModel> solidEnvironments,
) {
  final fieldByName = {for (final f in solidFields) f.fieldName: f};
  final envByName = {for (final e in solidEnvironments) e.fieldName: e};
  final getterByName = {for (final g in solidGetters) g.getterName: g};
  final effectByName = {for (final e in solidEffects) e.methodName: e};
  final queryByName = {for (final q in solidQueries) q.methodName: q};
  final reactiveTypeTexts = <String, String>{
    for (final f in solidFields) f.fieldName: f.typeText,
    for (final g in solidGetters) g.getterName: g.typeText,
  };
  final lines = <String>[];
  final disposeNames = <String>[];
  final effectNames = <String>[];

  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      final name = member.fields.variables.first.name.lexeme;
      final f = fieldByName[name];
      if (f != null) {
        lines.add(emitSignalField(f));
        disposeNames.add(f.fieldName);
        continue;
      }
      final env = envByName[name];
      if (env != null) {
        // No disposeNames / effectNames push — env fields are not host-
        // disposed (SPEC §10) and not initState-materialized (SPEC §4.9).
        lines.add(emitEnvironmentField(env));
      }
      continue;
    }
    if (member is MethodDeclaration) {
      final name = member.name.lexeme;
      if (member.isGetter) {
        final g = getterByName[name];
        if (g != null) {
          lines.add(emitComputedField(g));
          disposeNames.add(g.getterName);
        }
      } else if (!member.isSetter) {
        final e = effectByName[name];
        if (e != null) {
          lines.add(emitEffectField(e));
          disposeNames.add(e.methodName);
          effectNames.add(e.methodName);
          continue;
        }
        final q = queryByName[name];
        if (q != null) {
          emitQueryFields(q, reactiveTypeTexts, lines, disposeNames);
        }
      }
    }
  }

  return (
    fieldsText: lines.join('\n'),
    disposeNamesInDeclarationOrder: disposeNames,
    effectNamesInDeclarationOrder: effectNames,
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
/// declaration (Signal field + Computed getter + Effect method +
/// `@SolidEnvironment` env field) on the original class.
///
/// [effectNamesInDeclarationOrder] is the Effect-only subset of
/// [disposeNamesInDeclarationOrder]. When non-empty, this method emits a
/// synthesized `initState()` that materializes each `late final` Effect field
/// at mount time so its autorun fires (SPEC §4.7). When empty, no `initState`
/// is emitted — preserving byte-equality with every M1/M2/M3 golden that has
/// no Effects.
///
/// `dispose()` is similarly gated on [disposeNamesInDeclarationOrder] being
/// non-empty (SPEC §10): an env-only host class (M6-03) has no reactive
/// declarations to dispose, so no `dispose()` override is emitted — the
/// inherited `State<T>.dispose()` runs unchanged.
String _emitStateClass({
  required String className,
  required String stateClassName,
  required String reactiveFieldsText,
  required List<String> disposeNamesInDeclarationOrder,
  required List<String> effectNamesInDeclarationOrder,
  required String stateFieldsText,
  required String buildMethodText,
}) {
  final fieldsPrefix = stateFieldsText.isNotEmpty ? '$stateFieldsText\n\n' : '';
  final initStateBlock = effectNamesInDeclarationOrder.isEmpty
      ? ''
      : '${emitInitState(effectNamesInDeclarationOrder)}\n\n';
  final disposeBlock = disposeNamesInDeclarationOrder.isEmpty
      ? ''
      : '${emitDispose(
          disposeNamesInDeclarationOrder,
          emitOverride: true,
          emitSuperCall: true,
        )}\n\n';

  return '''
class $stateClassName extends State<$className> {
$fieldsPrefix$reactiveFieldsText

$initStateBlock$disposeBlock  $buildMethodText
}''';
}
