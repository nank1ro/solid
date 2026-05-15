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
import 'package:solid_generator/src/value_rewriter.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields,
/// `@SolidState` getters, `@SolidEffect` methods, and/or `@SolidQuery`
/// methods as a `StatefulWidget` + `State<X>` pair. The class is rewritten
/// as a `StatefulWidget` + `State<X>` pair with full field-partition and
/// constructor-preservation, getter→`Computed` lowering, method→`Effect`
/// lowering, and method→`Resource` lowering.
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
  Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, String>> classFieldTypes,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final reactiveNames = <String>{
    ...solidFields.map((f) => f.fieldName),
    ...solidGetters.map((g) => g.getterName),
  };
  // Subset of `reactiveNames` whose emitter produces a collection signal
  // (`ListSignal<T>` / `SetSignal<T>` / `MapSignal<K, V>`). Used by the
  // value-rewriter to skip `.value` on chain accesses and bare reads of
  // these fields — the mixin API resolves through the signal directly.
  final collectionNames = <String>{
    for (final f in solidFields)
      if (isCollectionSignalField(f)) f.fieldName,
  };
  // Query call expressions in `build` are tracked reads. Names are kept
  // separate from `reactiveNames` so the `.value` rewrite does not fire on
  // `<queryName>` identifiers.
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

  // Annotated methods are emitted by `_emitReactiveBlock` from their model
  // lists; the verbatim member walk in `_splitMembers` must NOT echo them
  // back as "other methods" or they would appear twice in the output.
  final annotatedMethodNames = <String>{
    ...solidEffects.map((e) => e.methodName),
    ...solidQueries.map((q) => q.methodName),
    ...solidGetters.map((g) => g.getterName),
  };
  final members = _splitMembers(classDecl, annotatedMethodNames);
  final widgetBoundNames = collectWidgetBoundNames(members.ctors);
  final partition = _partitionFields(
    members.fields,
    partitionExcludeNames,
    widgetBoundNames,
    source,
  );
  final classFieldsAreConstSafe = _classFieldsAreConstSafe(
    members.fields,
    widgetBoundNames,
    partitionExcludeNames,
  );
  final emittedCtors = _emitCtors(
    members.ctors,
    source,
    classFieldsAreConstSafe,
    className,
  );
  // Cross-class env-field receiver type map.
  final environmentFields = solidEnvironments.isEmpty
      ? const <String, String>{}
      : {for (final e in solidEnvironments) e.fieldName: e.typeText};
  // Widget→State scope shift: bare references inside `build` to a
  // widget-bound non-`@SolidState` field need a `widget.` prefix so the
  // State class resolves them through the widget config object. Subtract
  // `partitionExcludeNames` so reactive / env-field names (which leave the
  // widget half) are not mis-prefixed.
  final widgetBoundForBuild = widgetBoundNames.difference(
    partitionExcludeNames,
  );
  final buildMethodText = rewriteBuildMethod(
    members.buildMethod,
    reactiveNames,
    source,
    queryNames: queryNames,
    classRegistry: classRegistry,
    environmentFields: environmentFields,
    widgetBoundFields: widgetBoundForBuild,
    collectionFields: collectionNames,
    classCollectionFields: classCollectionFields,
  );

  final reactiveBlock = _emitReactiveBlock(
    classDecl,
    solidFields,
    solidGetters,
    solidEffects,
    solidQueries,
    solidEnvironments,
    environmentFields,
    classFieldTypes,
  );

  // Lifecycle merge (F-3): if the source `StatelessWidget` declared a
  // user-authored `dispose()` or `initState()`, route those through the same
  // merge helpers that `state_class_rewriter` uses for pre-existing
  // `State<X>` classes. The user's block-body statements are spliced AFTER
  // the synthesized reactive teardowns/materializations, so e.g. a Timer
  // cancel or StreamSubscription cancel in the user body runs after
  // generated `Effect.dispose()` / `Resource.dispose()` calls.
  final disposeText = _emitDisposeText(
    userDispose: members.userDispose,
    disposeNamesInDeclarationOrder:
        reactiveBlock.disposeNamesInDeclarationOrder,
    source: source,
    className: className,
  );
  final initStateText = _emitInitStateText(
    userInitState: members.userInitState,
    effectNamesInDeclarationOrder: reactiveBlock.effectNamesInDeclarationOrder,
    source: source,
    className: className,
  );
  // Non-`build`/`dispose`/`initState` user methods are preserved on the
  // synthesized `_FooState` so helpers (`_send`, `_format`, …) survive the
  // lift. Bodies run through `rewriteUserMethod` so cross-class signal reads
  // and same-class `@SolidState` writes get the same `.value` treatment they
  // already receive on `plain_class` and `state_class` rewriters.
  final environmentFieldsMap = environmentFields;
  final otherMethodsText = members.otherMethods
      .map(
        (m) =>
            '  ${rewriteUserMethod(
              m,
              reactiveNames,
              classRegistry,
              source,
              environmentFields: environmentFieldsMap,
              collectionFields: collectionNames,
              classCollectionFields: classCollectionFields,
            )}',
      )
      .join('\n\n');

  final widgetClass = _emitWidgetClass(
    className,
    stateClassName,
    emittedCtors.text,
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
    initStateText: initStateText,
    disposeText: disposeText,
    otherMethodsText: otherMethodsText,
  );

  // `Signal` and `SignalBuilder` are emitted when EITHER the class has its
  // own same-class reactive declaration OR the build body wraps a
  // cross-class tracked read in `SignalBuilder` (the env-injected receiver
  // shape — the consumer has no own state but reads through to a sibling
  // class's `@SolidState`). The textual scan on `buildMethodText` catches
  // the cross-class case without re-walking the AST.
  final hasReactive =
      solidFields.isNotEmpty ||
      solidGetters.isNotEmpty ||
      solidQueries.isNotEmpty;
  final buildEmitsSignalBuilder = buildMethodText.contains('SignalBuilder(');
  // A field's emitted ctor is one of: Signal / ListSignal / SetSignal /
  // MapSignal. Collection emitters bypass `Signal` entirely, so the import
  // set follows the per-field decision rather than blanket-adding `Signal`.
  final hasScalarSignalField = solidFields.any(
    (f) => !isCollectionSignalField(f),
  );
  final hasListSignalField = solidFields.any(
    (f) =>
        isCollectionSignalField(f) &&
        parseCollectionTypeText(f.typeText)?.ctorName == 'ListSignal',
  );
  final hasSetSignalField = solidFields.any(
    (f) =>
        isCollectionSignalField(f) &&
        parseCollectionTypeText(f.typeText)?.ctorName == 'SetSignal',
  );
  final hasMapSignalField = solidFields.any(
    (f) =>
        isCollectionSignalField(f) &&
        parseCollectionTypeText(f.typeText)?.ctorName == 'MapSignal',
  );
  final solidartNames = <String>{
    if (hasScalarSignalField) 'Signal',
    if (hasListSignalField) 'ListSignal',
    if (hasSetSignalField) 'SetSignal',
    if (hasMapSignalField) 'MapSignal',
    if (hasReactive || buildEmitsSignalBuilder) 'SignalBuilder',
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
    emitsDisposable: false,
    constCtorNames: emittedCtors.constCtorNames,
  );
}

/// Returns the source-ordered emission of every reactive declaration on
/// [classDecl] (Signal field + Computed getter + Effect method + Resource
/// query + `@SolidEnvironment` env field) as a single 2-space-indented block,
/// plus the declaration-order list of dispose names that pairs with it.
/// Source order is the contract that `Computed`, `Effect`, and the
/// query-source-Computed depend on: each must reference declarations defined
/// before it, so the emitted `late final` lines must appear after the
/// declarations they read in the rewritten State class.
///
/// `effectNamesInDeclarationOrder` is the Effect-only subset of
/// `disposeNamesInDeclarationOrder`, pulled out so the rewriter can
/// synthesize `initState()` that materializes each `late final` Effect field
/// at mount time. Queries are intentionally NOT in this list — Resources are
/// lazy and the late-final initializer fires on first call-site read, never
/// via `initState`.
///
/// `@SolidEnvironment` env fields are emitted in source-declaration order
/// alongside Signal/Computed/Effect/Resource fields but are NEVER added to
/// `disposeNames` (env fields are not host-disposed) and NEVER added to
/// `effectNames` (env fields are lazy and need no initState materialization).
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
  Map<String, String> environmentFields,
  Map<String, Map<String, String>> classFieldTypes,
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
  // Cross-query deps: each upstream's inner `T` is needed to emit
  // `ResourceState<T>` elements in the synthesized source-Computed.
  final queryInnerTypeTexts = solidQueries.isEmpty
      ? const <String, String>{}
      : {for (final q in solidQueries) q.methodName: q.innerTypeText};
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
        // disposed and not initState-materialized.
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
          emitQueryFields(
            q,
            reactiveTypeTexts,
            queryInnerTypeTexts,
            environmentFields,
            classFieldTypes,
            lines,
            disposeNames,
          );
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
/// `StatelessWidget`.
({
  List<ConstructorDeclaration> ctors,
  List<FieldDeclaration> fields,
  MethodDeclaration buildMethod,
  MethodDeclaration? userInitState,
  MethodDeclaration? userDispose,
  List<MethodDeclaration> otherMethods,
})
_splitMembers(ClassDeclaration classDecl, Set<String> annotatedMethodNames) {
  final ctors = <ConstructorDeclaration>[];
  final fields = <FieldDeclaration>[];
  final otherMethods = <MethodDeclaration>[];
  MethodDeclaration? buildMethod;
  MethodDeclaration? userInitState;
  MethodDeclaration? userDispose;
  for (final member in classDecl.members) {
    if (member is ConstructorDeclaration) {
      ctors.add(member);
    } else if (member is FieldDeclaration) {
      fields.add(member);
    } else if (member is MethodDeclaration) {
      final name = member.name.lexeme;
      if (name == 'build') {
        buildMethod = member;
      } else if (name == 'initState') {
        userInitState = member;
      } else if (name == 'dispose') {
        userDispose = member;
      } else if (annotatedMethodNames.contains(name)) {
        // @SolidEffect / @SolidQuery / @SolidState getter — emitted from
        // its model in `_emitReactiveBlock`. Skip here to avoid duplication.
        continue;
      } else {
        otherMethods.add(member);
      }
    }
  }
  if (buildMethod == null) {
    throw AnalysisError(
      'StatelessWidget has no build() method to preserve',
      null,
      classDecl.name.lexeme,
    );
  }
  return (
    ctors: ctors,
    fields: fields,
    buildMethod: buildMethod,
    userInitState: userInitState,
    userDispose: userDispose,
    otherMethods: otherMethods,
  );
}

/// Union of field names bound by any **generative** constructor in [ctors] —
/// either as a `this.X` formal parameter or as the LHS of an init-list field
/// assignment. Factory constructors are skipped: their body returns an
/// instance via redirection or a regular method call and never binds a field
/// directly to a parameter. (`ConstructorDeclaration` exposes only
/// `factoryKeyword` in the public analyzer API; there is no `isFactory`
/// getter, hence the null-check.)
Set<String> collectWidgetBoundNames(Iterable<ConstructorDeclaration> ctors) {
  final names = <String>{};
  for (final ctor in ctors) {
    if (ctor.factoryKeyword != null) continue;
    for (final param in ctor.parameters.parameters) {
      final inner = _unwrapDefault(param);
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

/// Strips the `DefaultFormalParameter` wrapper so the inner shape
/// (`FieldFormalParameter`, `SuperFormalParameter`, …) can be type-checked
/// directly. Default values and `required`/`covariant` modifiers live on
/// the wrapper and are immaterial to const-eligibility / field-binding
/// decisions.
FormalParameter _unwrapDefault(FormalParameter p) =>
    p is DefaultFormalParameter ? p.parameter : p;

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

/// Emits every constructor 2-space indented and joined by blank lines,
/// prefixing `const ` on each ctor that is statically determinable
/// const-eligible. Returns an empty `text` when [ctors] is empty (Dart
/// synthesises the implicit default constructor on the rewritten class).
///
/// [classFieldsAreConstSafe] is the class-level gate: false when any
/// retained widget-bound non-`@SolidState` instance field is non-final
/// (and non-static / non-const), in which case NO ctor on the class can
/// be const regardless of its own shape. When true, each ctor is checked
/// individually via [_isConstEligibleCtor].
///
/// `constCtorNames` enumerates the constructor invocation names that gained
/// `const` — `"$className"` for the unnamed ctor, `"$className.<name>"` for
/// named ctors — used by the post-emit call-site rewriter to decide which
/// `InstanceCreationExpression`s elsewhere in the output to promote.
({String text, Set<String> constCtorNames}) _emitCtors(
  List<ConstructorDeclaration> ctors,
  String source,
  bool classFieldsAreConstSafe,
  String className,
) {
  if (ctors.isEmpty) return (text: '', constCtorNames: const <String>{});
  final constCtorNames = <String>{};
  final pieces = <String>[];
  for (final c in ctors) {
    final ctorText = source.substring(c.offset, c.end);
    final addConst = classFieldsAreConstSafe && _isConstEligibleCtor(c);
    if (addConst) {
      final name = c.name?.lexeme;
      constCtorNames.add(name == null ? className : '$className.$name');
      pieces.add('  const $ctorText');
    } else {
      pieces.add('  $ctorText');
    }
  }
  return (text: pieces.join('\n\n'), constCtorNames: constCtorNames);
}

/// Returns true iff [ctor] alone meets the per-ctor const-eligibility
/// conditions: it is generative (not factory/external) and not already
/// declared `const`; every parameter forwards via `this.<name>`
/// (FieldFormalParameter) or `super.<name>` (SuperFormalParameter); the
/// body is empty (`;` or `{}`); the initializer list is either absent or
/// contains only [ConstructorFieldInitializer] entries whose RHS is a basic
/// literal per [_isLiteralRhs]. AssertInitializer,
/// RedirectingConstructorInvocation, SuperConstructorInvocation, and any
/// non-literal RHS disqualify.
///
/// The class-level gate (every retained widget-bound instance field is
/// final) is checked separately by [_classFieldsAreConstSafe] — this
/// function does NOT inspect fields.
bool _isConstEligibleCtor(ConstructorDeclaration ctor) {
  if (ctor.factoryKeyword != null) return false;
  if (ctor.externalKeyword != null) return false;
  if (ctor.constKeyword != null) return false;
  for (final param in ctor.parameters.parameters) {
    final inner = _unwrapDefault(param);
    if (inner is! FieldFormalParameter && inner is! SuperFormalParameter) {
      return false;
    }
  }
  final body = ctor.body;
  final hasEmptyBody =
      body is EmptyFunctionBody ||
      (body is BlockFunctionBody && body.block.statements.isEmpty);
  if (!hasEmptyBody) return false;
  for (final initializer in ctor.initializers) {
    if (initializer is! ConstructorFieldInitializer) return false;
    if (!_isLiteralRhs(initializer.expression)) return false;
  }
  return true;
}

/// Returns true iff [expr] is one of the basic literal forms that are
/// always const-evaluable. Conservative subset of the Dart spec's "contains
/// only const expressions" clause; covers the known corpus and is trivially
/// extensible to cover other forms (`const C(...)`, `AdjacentStrings`,
/// identifier reads of static const fields, ...) later.
bool _isLiteralRhs(Expression expr) {
  return expr is BooleanLiteral ||
      expr is DoubleLiteral ||
      expr is IntegerLiteral ||
      expr is NullLiteral ||
      expr is SimpleStringLiteral ||
      expr is SymbolLiteral;
}

/// Returns true iff every retained widget-bound non-`@SolidState` instance
/// field of the original class is `final` (or `const` / `static`). A non-
/// final non-const non-static instance field on the lowered StatefulWidget
/// half makes it impossible for ANY constructor on the class to be const,
/// regardless of the constructor's own shape — so this is the class-level
/// gate paired with [_isConstEligibleCtor]'s per-ctor checks.
///
/// `late final` counts as final (the `late` modifier is orthogonal to
/// finality). Static fields are skipped because they don't participate in
/// instance construction. Const fields are also skipped because they're
/// already immutable.
bool _classFieldsAreConstSafe(
  List<FieldDeclaration> fields,
  Set<String> widgetBoundNames,
  Set<String> partitionExcludeNames,
) {
  for (final f in fields) {
    final name = f.fields.variables.first.name.lexeme;
    if (partitionExcludeNames.contains(name)) continue;
    if (!widgetBoundNames.contains(name)) continue;
    if (f.isStatic) continue;
    if (f.fields.isFinal) continue;
    if (f.fields.isConst) continue;
    return false;
  }
  return true;
}

/// Emits the public `StatefulWidget` half of the class split.
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

/// Returns the `dispose()` text to splice into the synthesized `State<X>`.
///
/// Three cases:
/// 1. User wrote a `dispose()` AND there are reactive disposables → merge
///    via [mergeDispose] (reactive teardowns prepended to user body),
///    then append `super.dispose();` (the source-side `StatelessWidget` has
///    no `dispose` to invoke as super, so the user can't write it; the
///    lifted `State<X>` requires it).
/// 2. User wrote a `dispose()` AND no reactive disposables → preserve user
///    body verbatim and append `super.dispose();` for the same reason.
/// 3. No user `dispose()` AND there are reactive disposables → synthesize
///    via [emitDispose] with super-call appended.
/// 4. No user `dispose()` AND no reactive disposables → no `dispose()`
///    override; the inherited `State<T>.dispose()` runs unchanged.
String _emitDisposeText({
  required MethodDeclaration? userDispose,
  required List<String> disposeNamesInDeclarationOrder,
  required String source,
  required String className,
}) {
  if (userDispose != null) {
    final body = disposeNamesInDeclarationOrder.isEmpty
        ? source.substring(userDispose.offset, userDispose.end)
        : mergeDispose(
            userDispose,
            disposeNamesInDeclarationOrder,
            source,
            className,
          );
    return '  ${_appendSuperDispose(body)}';
  }
  if (disposeNamesInDeclarationOrder.isEmpty) return '';
  return emitDispose(
    disposeNamesInDeclarationOrder,
    emitOverride: true,
    emitSuperCall: true,
  );
}

/// Returns [methodText] with `    super.dispose();` spliced in immediately
/// before its closing brace. The input is assumed to be the source text of
/// a block-body `void dispose() { ... }` method (the post-merge or
/// pre-merge form). The brace search walks from the end backwards — robust
/// against trailing whitespace.
String _appendSuperDispose(String methodText) {
  final closeIdx = methodText.lastIndexOf('}');
  return '${methodText.substring(0, closeIdx)}'
      '  super.dispose();\n  '
      '${methodText.substring(closeIdx)}';
}

/// Returns the `initState()` text to splice into the synthesized `State<X>`.
///
/// Same four-case structure as [_emitDisposeText], but with [mergeInitState]
/// and [emitInitState] in the reactive/synthesized branches.
String _emitInitStateText({
  required MethodDeclaration? userInitState,
  required List<String> effectNamesInDeclarationOrder,
  required String source,
  required String className,
}) {
  if (userInitState != null) {
    final body = effectNamesInDeclarationOrder.isEmpty
        ? source.substring(userInitState.offset, userInitState.end)
        : mergeInitState(
            userInitState,
            effectNamesInDeclarationOrder,
            source,
            className,
          );
    return '  ${_prependSuperInitState(body, userInitState)}';
  }
  if (effectNamesInDeclarationOrder.isEmpty) return '';
  return emitInitState(effectNamesInDeclarationOrder);
}

/// Returns [methodText] with `super.initState();` ensured as the first
/// statement in the block. The source-side `StatelessWidget` cannot legally
/// invoke `super.initState();` (no such method exists on `StatelessWidget`),
/// so the lift path inserts it on the user's behalf. If the user's source
/// already started with `super.initState();` (a non-conforming shape that
/// the source compiler would have rejected, but kept here as a defence),
/// no second copy is added.
String _prependSuperInitState(String methodText, MethodDeclaration userMethod) {
  final body = userMethod.body;
  if (body is! BlockFunctionBody) return methodText;
  final stmts = body.block.statements;
  if (stmts.isNotEmpty && _isSuperInitStateCall(stmts.first)) {
    return methodText;
  }
  // Insert `super.initState();` immediately after the first `{` in the
  // merged/preserved method text. The brace search is bounded to the first
  // occurrence, which is always the body's opening brace (method headers
  // never contain `{`).
  final openIdx = methodText.indexOf('{');
  return '${methodText.substring(0, openIdx + 1)}'
      '\n    super.initState();'
      '${methodText.substring(openIdx + 1)}';
}

bool _isSuperInitStateCall(Statement stmt) {
  if (stmt is! ExpressionStatement) return false;
  final expr = stmt.expression;
  if (expr is! MethodInvocation) return false;
  return expr.target is SuperExpression && expr.methodName.name == 'initState';
}

/// Emits the private `State<X>` half of the class split.
///
/// `State<T>` has `dispose()` in its supertype chain, so the synthesized
/// `dispose()` is `@override` and ends with `super.dispose();`.
/// [stateFieldsText] is the verbatim source of every non-`@SolidState`
/// non-widget-bound field that has been moved off the widget; emitted before
/// the synthesized reactive fields so original declaration order is preserved.
/// [reactiveFieldsText] is the source-ordered emission of every reactive
/// declaration (Signal field + Computed getter + Effect method +
/// `@SolidEnvironment` env field) on the original class.
///
/// [initStateText] and [disposeText] are precomputed by [_emitInitStateText]
/// and [_emitDisposeText] respectively — either synthesized from the
/// declaration-order name lists or merged with the user's source method.
/// They are empty strings when no `initState`/`dispose` override should be
/// emitted (no reactive disposables AND no user-written method).
///
/// [otherMethodsText] is the post-`rewriteUserMethod` form of every non-
/// `build`/`dispose`/`initState`/annotated method, joined as a single
/// indented block appended after the `build` method.
String _emitStateClass({
  required String className,
  required String stateClassName,
  required String reactiveFieldsText,
  required List<String> disposeNamesInDeclarationOrder,
  required List<String> effectNamesInDeclarationOrder,
  required String stateFieldsText,
  required String buildMethodText,
  required String initStateText,
  required String disposeText,
  required String otherMethodsText,
}) {
  final fieldsPrefix = stateFieldsText.isNotEmpty ? '$stateFieldsText\n\n' : '';
  final initStateBlock = initStateText.isEmpty ? '' : '$initStateText\n\n';
  final disposeBlock = disposeText.isEmpty ? '' : '$disposeText\n\n';
  final otherMethodsBlock = otherMethodsText.isEmpty
      ? ''
      : '\n\n$otherMethodsText';

  return '''
class $stateClassName extends State<$className> {
$fieldsPrefix$reactiveFieldsText

$initStateBlock$disposeBlock  $buildMethodText$otherMethodsBlock
}''';
}
