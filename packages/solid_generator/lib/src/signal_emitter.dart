import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Shared signal-emission helpers used by every class-kind rewriter.

/// Parsed shape of a collection-type `@SolidState` field — the constructor
/// name (`'ListSignal'` / `'SetSignal'` / `'MapSignal'`) and the inner type-
/// argument text (e.g. `'Todo'` for `List<Todo>`, `'String, int'` for
/// `Map<String, int>`).
///
/// Returned by [parseCollectionTypeText]; consumed by [emitSignalField] and
/// the rewriters that build the collection-fields name set.
typedef CollectionSignalKind = ({String ctorName, String innerType});

/// Returns the collection-signal kind for [typeText] when it names a
/// top-level `List<T>`, `Set<T>`, or `Map<K, V>` — otherwise `null`.
///
/// Pure textual: matches `^(List|Set|Map)<...>$` shapes. Nested generics
/// (`List<List<int>>`) round-trip through the inner-text slice. The match
/// is conservative — `Iterable<int>`, namespace-prefixed aliases
/// (`core.List<int>`), and user-defined names that happen to start with
/// `List<` (none exist in `dart:core`) are intentionally NOT matched and
/// fall through to plain `Signal<T>`.
CollectionSignalKind? parseCollectionTypeText(String typeText) {
  if (typeText.startsWith('List<') && typeText.endsWith('>')) {
    return (
      ctorName: 'ListSignal',
      innerType: typeText.substring(5, typeText.length - 1),
    );
  }
  if (typeText.startsWith('Set<') && typeText.endsWith('>')) {
    return (
      ctorName: 'SetSignal',
      innerType: typeText.substring(4, typeText.length - 1),
    );
  }
  if (typeText.startsWith('Map<') && typeText.endsWith('>')) {
    return (
      ctorName: 'MapSignal',
      innerType: typeText.substring(4, typeText.length - 1),
    );
  }
  return null;
}

/// True iff [emitSignalField] would emit a collection-signal constructor
/// (`ListSignal` / `SetSignal` / `MapSignal`) for [f]. The contract: the
/// declared type matches [parseCollectionTypeText] AND the field is
/// non-nullable.
///
/// `late` is NOT a barrier — collection signals are mutated in place (the
/// reference stays final; the contents change via mixin methods), so a
/// `late List<T> xs;` source field can still lower to a `ListSignal<T>`
/// initialised to an empty literal. Only nullable types still fall back
/// to plain `Signal<T?>` because collection signals reject null at the
/// signal level.
bool isCollectionSignalField(FieldModel f) {
  if (f.isNullable) return false;
  return parseCollectionTypeText(f.typeText) != null;
}

/// Returns a MUTABLE empty-literal source for a collection-signal
/// initializer when the source field has no explicit `= …` clause.
///
/// `const` is intentionally NOT emitted: a collection signal forwards
/// mutations to the wrapped collection via `ListMixin` / `SetMixin` /
/// `MapMixin`, so an unmodifiable empty literal would throw
/// `UnsupportedError` on the first write.
String _emptyCollectionLiteral(CollectionSignalKind kind) {
  switch (kind.ctorName) {
    case 'ListSignal':
      return '<${kind.innerType}>[]';
    case 'SetSignal':
    case 'MapSignal':
      return '<${kind.innerType}>{}';
  }
  // Unreachable — `parseCollectionTypeText` only produces these three names.
  throw StateError('unknown collection ctor: ${kind.ctorName}');
}

/// Emits one `[late ]final <name> = Signal<T>(…, name: '<debug>');` line.
///
/// Collection fields (`List<T>` / `Set<T>` / `Map<K, V>`, non-nullable)
/// lower to `ListSignal<T>` / `SetSignal<T>` / `MapSignal<K, V>` regardless
/// of `late`. The user's `= …` clause is spliced verbatim when present;
/// otherwise an empty literal (`<T>[]` / `<T>{}` / `<K, V>{}`) is used. The
/// collection-signal mixin tracks reads through the same channels `.value`
/// would, so `late` adds no value here (and collection signals don't expose
/// `.lazy` anyway).
///
/// A `const` user initializer is rejected with a `CodeGenerationError`:
/// the lowered collection signal forwards mutations through `ListMixin` /
/// `SetMixin` / `MapMixin` to the wrapped collection, so a `const` literal
/// throws `UnsupportedError` on the first write. The error surfaces at
/// build time instead of lying dormant until the first user mutation.
///
/// Non-collection (scalar) cases, in priority order:
///
/// 1. **Has initializer** → `Signal<T>(<init>, name: '<debug>')`. The
///    `late` modifier (if any) is preserved verbatim so that `Signal`
///    construction itself is deferred to first access.
/// 2. **No initializer, nullable type** → `Signal<T?>(null, name: '…')`.
///    No `late` needed because `null` is a valid default.
/// 3. **No initializer, non-nullable type** →
///    `Signal<T>.lazy(name: '…')`. The source field must have been
///    declared `late`; reads before the first write throw `StateError`,
///    matching Dart's own `late` semantics.
String emitSignalField(FieldModel f) {
  final debugName = f.annotationName ?? f.fieldName;
  final lateKw = f.isLate ? 'late ' : '';
  final String ctor;
  if (isCollectionSignalField(f)) {
    final collection = parseCollectionTypeText(f.typeText)!;
    final constPrefix = RegExp(r'^const\s+');
    if (constPrefix.hasMatch(f.initializerText)) {
      final mutableExample = f.initializerText.replaceFirst(constPrefix, '');
      throw CodeGenerationError(
        '@SolidState() collection field `${f.fieldName}` has a `const` '
        'initializer:\n'
        '  ${f.typeText} ${f.fieldName} = ${f.initializerText};\n'
        'A `const` literal is unmodifiable — the lowered '
        '${collection.ctorName} would throw `UnsupportedError` on the '
        'first write. Drop the `const` so the collection signal wraps a '
        'mutable copy:\n'
        '  ${f.typeText} ${f.fieldName} = $mutableExample;',
        null,
        f.fieldName,
      );
    }
    final init = f.initializerText.isNotEmpty
        ? f.initializerText
        : _emptyCollectionLiteral(collection);
    ctor =
        '${collection.ctorName}<${collection.innerType}>'
        "($init, name: '$debugName')";
  } else if (f.initializerText.isNotEmpty) {
    ctor = "Signal<${f.typeText}>(${f.initializerText}, name: '$debugName')";
  } else if (f.isNullable) {
    ctor = "Signal<${f.typeText}>(null, name: '$debugName')";
  } else {
    ctor = "Signal<${f.typeText}>.lazy(name: '$debugName')";
  }
  return '  ${lateKw}final ${f.fieldName} = $ctor;';
}

/// Emits one `late final <name> = Computed<T>(<closure>, name: '<debug>');`
/// line per getter body kind (expression body or block body).
///
/// The result is always `late final` because a `Computed` references other
/// `final` instance fields whose initialization order is not guaranteed
/// at declaration time. The body text in [g] has already had the
/// `.value` rewrite applied by `readSolidStateGetter`, so the
/// emitter splices it directly into the closure. The closure shape depends
/// on `g.isBlockBody`:
///
/// * Expression body → `() => <bodyText>`.
/// * Block body → `() <bodyText>` (where `bodyText` already includes the
///   surrounding `{ ... }` braces, copied verbatim from the source).
String emitComputedField(GetterModel g) {
  final debugName = g.annotationName ?? g.getterName;
  final closure = g.isBlockBody ? '() ${g.bodyText}' : '() => ${g.bodyText}';
  final ctor = "Computed<${g.typeText}>($closure, name: '$debugName')";
  return '  late final ${g.getterName} = $ctor;';
}

/// Emits one `late final <name> = Effect(<closure>, name: '<debug>');` line.
/// Mirrors [emitComputedField] (same closure shape, same `late final`
/// rationale, same body-text contract); the only differences are the absent
/// type parameter and the `Effect` ctor.
///
/// `Effect(...)` takes a zero-param `void Function()` callback per the
/// upstream `flutter_solidart` API and returns an `Effect` object whose
/// `.dispose()` joins the unified disposal list emitted by [emitDispose].
String emitEffectField(EffectModel e) {
  final debugName = e.annotationName ?? e.methodName;
  final closure = e.isBlockBody ? '() ${e.bodyText}' : '() => ${e.bodyText}';
  final ctor = "Effect($closure, name: '$debugName')";
  return '  late final ${e.methodName} = $ctor;';
}

/// Emits one `late final <name> = Resource<T>(<closure>, name: '<debug>');`
/// (Future form) or the `Resource<T>.stream(...)` named-constructor variant
/// (Stream form). Mirrors [emitEffectField]'s closure-shape contract — same
/// `late final` rationale, same body-text contract — but adds:
///
/// * a type argument `Resource<T>` peeled from the source `Future<T>` /
///   `Stream<T>` return type (carried on [QueryModel.innerTypeText]),
/// * the upstream `.stream` named constructor when [QueryModel.isStream] is
///   true (its fetcher signature is `Stream<T> Function()`, not the default
///   `Future<T> Function()`),
/// * the source body keyword spliced verbatim into the closure signature
///   ([QueryModel.bodyKeyword] is one of `'async'`, `'async*'`, or `''`), and
/// * a public field name (no underscore prefix) — a single emitted declaration
///   per query.
///
/// The Resource field always joins the unified ordered dispose list managed
/// by [emitDispose]. Resources are NEVER materialized in `initState()` /
/// the synthesized constructor — the lazy `late final` initializer fires on
/// first read at the first reactive call site.
String emitResourceField(QueryModel q) {
  final debugName = q.annotationName ?? q.methodName;
  final asyncKw = q.bodyKeyword.isEmpty ? '' : '${q.bodyKeyword} ';
  final closure = q.isBlockBody
      ? '() $asyncKw${q.bodyText}'
      : '() $asyncKw=> ${q.bodyText}';
  final ctorName = q.isStream
      ? 'Resource<${q.innerTypeText}>.stream'
      : 'Resource<${q.innerTypeText}>';
  // A single-observable Computed wrapper would be a no-op, so the one-dep
  // case (whether a state Signal or an upstream Resource) passes the
  // observable directly as `source:`. State deps come from
  // `trackedSignalNames`; query deps come from `trackedQueryNames` and pass
  // the upstream `Resource<T>` field directly (Resource extends Signal so it
  // qualifies as a `SignalBase<dynamic>` source — auto-tracking of upstream
  // queries).
  // `useRefreshing: true` is the upstream default and is omitted from emitted
  // output to keep generated lines short.
  final source = switch ((q.trackedSignalNames, q.trackedQueryNames)) {
    ([], []) => null,
    ([final only], []) => only,
    ([], [final only]) => only,
    _ => q.sourceFieldName,
  };
  final args = [
    closure,
    if (source != null) 'source: $source',
    if (q.debounce != null) 'debounceDelay: ${q.debounce}',
    if (q.useRefreshing == false) 'useRefreshing: false',
    "name: '$debugName'",
  ].join(', ');
  return '  late final ${q.methodName} = $ctorName($args);';
}

/// Emits one `late final <fieldName> = context.read<<T>>();` line per
/// `@SolidEnvironment` field. Env fields are NEVER added to the
/// dispose-name list (the providing `Provider<T>` owns disposal) and NEVER
/// materialized in `initState` (they're lazy).
String emitEnvironmentField(EnvironmentModel e) {
  return '  late final ${e.fieldName} = context.read<${e.typeText}>();';
}

/// Emits the synthesized Record-Computed source field for an `@SolidQuery`
/// method whose body reads two or more `@SolidState` field/getter
/// identifiers (multi-dep case). Shape:
///
/// ```dart
/// late final _<methodName>Source = Computed<(T1, T2, …)>(
///   () => (s1.value, s2.value, …),
///   name: '_<methodName>Source',
/// );
/// ```
///
/// Returns `null` for queries whose body reads zero or one upstream reactives:
/// no synthesized field is needed in either case (zero → no `source:`; one →
/// the existing Signal/Computed is passed directly as `source:`). The return
/// type advertises that contract: the caller branches on `null` to know
/// whether to emit a source field and add it to the dispose-name list.
///
/// [reactiveTypeTexts] maps each `@SolidState` field/getter name on the
/// enclosing class to its declared inner type text (e.g. `'int'`, `'String?'`).
/// The map is built by the caller from `solidFields` / `solidGetters` before
/// the per-member walk. Each tracked name's type becomes the corresponding
/// element in the `(T1, T2, …)` Record type literal.
///
/// Throws [CodeGenerationError] when any tracked name resolves to an empty
/// type text — explicit type annotations are required on `@SolidState`
/// fields/getters, and a missing one would produce invalid Dart in the
/// emitted Record-Computed type argument.
///
/// The synthesized field name `_<methodName>Source` could in theory collide
/// with a user-declared private member; this is consistent with other
/// generator-synthesized names (e.g. the `_<className>State` partner class in
/// `stateless_rewriter`) and intentionally not validator-checked at this
/// milestone — a future milestone may add a collision pass if needed.
String? emitQuerySourceField(
  QueryModel q,
  Map<String, String> reactiveTypeTexts,
  Map<String, String> queryInnerTypeTexts,
) {
  if (!q.needsSourceComputed) return null;
  // State deps contribute element type `T` and read expression `<name>.value`;
  // query deps contribute element type `ResourceState<T>` and read expression
  // `<name>.state`. Source order is preserved across the merged list (state
  // names first per body appearance, then query names per body appearance —
  // matches the visitor's two parallel name lists).
  final stateTypes = q.trackedSignalNames.map((n) {
    final t = reactiveTypeTexts[n];
    if (t == null || t.isEmpty) {
      throw CodeGenerationError(
        "@SolidQuery '${q.methodName}' depends on reactive '$n' which has "
        'no explicit type annotation; add a type to the @SolidState '
        'declaration so the synthesized source-Computed Record type can be '
        'emitted',
        null,
        q.methodName,
      );
    }
    return t;
  }).toList();
  final queryTypes = q.trackedQueryNames.map((n) {
    final t = queryInnerTypeTexts[n];
    if (t == null || t.isEmpty) {
      throw CodeGenerationError(
        "@SolidQuery '${q.methodName}' depends on @SolidQuery '$n' which has "
        'no inner type argument; declare an explicit `Future<T>` / `Stream<T>` '
        'return type on the upstream query so the synthesized source-Computed '
        'Record type can be emitted as `ResourceState<T>`',
        null,
        q.methodName,
      );
    }
    return 'ResourceState<$t>';
  }).toList();
  final tupleType = '(${[...stateTypes, ...queryTypes].join(', ')})';
  final stateReads = q.trackedSignalNames.map((n) => '$n.value');
  final queryReads = q.trackedQueryNames.map((n) => '$n.state');
  final tupleExpr = '(${[...stateReads, ...queryReads].join(', ')})';
  final fieldName = q.sourceFieldName;
  return '  late final $fieldName = '
      "Computed<$tupleType>(() => $tupleExpr, name: '$fieldName');";
}

/// Emits the per-query field block used by all three rewriters: a synthesized
/// source Computed (when [QueryModel.needsSourceComputed]) immediately before
/// the Resource field. Both fields are appended to [output] in source-
/// declaration order, and their names are appended to [disposeNames] in the
/// same order — so reverse-disposal tears down the Resource first, then the
/// source Computed, then the underlying Signals.
///
/// [queryInnerTypeTexts] maps each `@SolidQuery` method name on the
/// enclosing class to its inner `T` (e.g. `'int'` for a `Future<int>` query).
/// Consumed by [emitQuerySourceField] to emit `ResourceState<T>` Record
/// element types for cross-query deps.
void emitQueryFields(
  QueryModel q,
  Map<String, String> reactiveTypeTexts,
  Map<String, String> queryInnerTypeTexts,
  List<String> output,
  List<String> disposeNames,
) {
  final sourceField = emitQuerySourceField(
    q,
    reactiveTypeTexts,
    queryInnerTypeTexts,
  );
  if (sourceField != null) {
    output.add(sourceField);
    disposeNames.add(q.sourceFieldName);
  }
  output.add(emitResourceField(q));
  disposeNames.add(q.methodName);
}

/// Emits a `dispose()` method disposing every name in
/// [disposeNamesInDeclarationOrder] in **reverse declaration order**.
///
/// The list is the unified, source-ordered sequence of every reactive
/// declaration (Signal field + Computed getter + Effect method) on the owning
/// class. Reverse-iterating it puts dependents (an `Effect` or `Computed`
/// declared after the `Signal`s it reads) ahead of their dependencies in the
/// dispose body.
///
/// [emitOverride] gates the `@override` annotation. Pass `true` when the
/// emitted `dispose()` overrides a supertype declaration — either `State<T>`
/// (whose supertype chain has `dispose()`) or `Disposable` (the
/// `solid_annotations` marker interface that lowered plain classes implement).
///
/// [emitSuperCall] gates the trailing `super.dispose();` line. Pass `true`
/// only when the class's supertype chain actually contains a `dispose()`
/// method to forward to (e.g. `State<T>`, `ChangeNotifier`). For a plain
/// class whose supertype is `Object` and which `implements Disposable`,
/// pass `false` — there is no super-`dispose()` to call.
String emitDispose(
  List<String> disposeNamesInDeclarationOrder, {
  required bool emitOverride,
  required bool emitSuperCall,
}) {
  final buffer = StringBuffer();
  if (emitOverride) {
    buffer.writeln('  @override');
  }
  buffer.writeln('  void dispose() {');
  for (final name in disposeNamesInDeclarationOrder.reversed) {
    buffer.writeln('    $name.dispose();');
  }
  if (emitSuperCall) {
    buffer.writeln('    super.dispose();');
  }
  buffer.write('  }');
  return buffer.toString();
}

/// Prepends one `<name>.dispose();` call per reactive declaration to the
/// existing `dispose()` body's leading boundary, leaving the rest of the body
/// untouched.
///
/// Shared by `state_class_rewriter` and `plain_class_rewriter` so the
/// dispose-body merge contract stays single-sourced. The user's source body
/// — including any `@override` annotation, return type, and existing
/// statements (e.g. `unawaited(_subscription.cancel());`) — is sliced
/// verbatim from `source.substring(method.offset, method.end)` and a single
/// `\n<disposals>` block is spliced immediately after the body's opening
/// brace. When the user's source `dispose()` lacks `@override`, the
/// generator prepends one: the merged dispose always overrides — either
/// `Disposable.dispose()` (plain class marker rule) or the supertype's
/// `dispose()` (`State<X>`) — so the lowered output is lint-clean against
/// `annotate_overrides`.
///
/// [disposeNamesInDeclarationOrder] is the unified, source-ordered list of
/// reactive declarations (Signal field + Effect method + Resource query).
/// Reverse-iterating it puts dependents (Effects, Resources) ahead of their
/// dependencies (Signals, Computeds) in the merged dispose body — matching
/// the unmerged [emitDispose] case.
///
/// Throws [CodeGenerationError] if the existing `dispose()` uses an
/// expression body (`=> …`) — the merge is only well-defined for a block.
String mergeDispose(
  MethodDeclaration method,
  List<String> disposeNamesInDeclarationOrder,
  String source,
  String className,
) {
  final body = method.body;
  if (body is! BlockFunctionBody) {
    throw CodeGenerationError(
      'existing dispose() must have a block body for reactive merge',
      null,
      className,
    );
  }
  final lbrace = body.block.leftBracket.offset;
  // The original source after `{` already begins with `\n` (the body's first
  // line break) on every reasonable formatting; prepending `\n<disposals>`
  // yields a single blank-line-free splice, leaving the rest of the body
  // byte-identical to the source. The `DartFormatter` pass normalises any
  // residual whitespace.
  final disposals = disposeNamesInDeclarationOrder.reversed
      .map((name) => '    $name.dispose();')
      .join('\n');
  // Auto-add `@override` if the user omitted it — see the function-level
  // doc comment for the contract.
  final hasOverride = method.metadata.any((a) => a.name.name == 'override');
  final overridePrefix = hasOverride ? '' : '@override\n  ';
  return '$overridePrefix${source.substring(method.offset, lbrace + 1)}'
      '\n$disposals'
      '${source.substring(lbrace + 1, method.end)}';
}

/// Emits an `initState()` method that materializes every `late final` Effect
/// field by reading it as a bare-identifier statement (`<effectName>;`), in
/// source-declaration order.
///
/// In Dart, `late final field = expr` defers the initializer until the field
/// is first read. Without this synthesized read, the Effect's factory
/// constructor — and its `effect.run()` autorun, which registers reactive
/// dependencies — would never fire during the widget's mounted lifetime. The
/// `dispose()` body's `<effectName>.dispose()` call is the first read, by
/// which point signal mutations have already happened.
///
/// Touching each Effect by name in `initState` triggers the `late final`
/// initializer at mount time, so `Effect(...)`'s autorun runs once with the
/// initial signal values and subscribes to subsequent changes.
///
/// [effectNamesInDeclarationOrder] should mirror the source order of the
/// emitted `late final … = Effect(...)` fields. Caller is responsible for
/// only invoking this when the list is non-empty — the resulting `initState`
/// is otherwise a pure-overhead `super.initState()` no-op.
String emitInitState(List<String> effectNamesInDeclarationOrder) {
  final buffer = StringBuffer()
    ..writeln('  @override')
    ..writeln('  void initState() {')
    ..writeln('    super.initState();');
  for (final name in effectNamesInDeclarationOrder) {
    buffer.writeln('    $name;');
  }
  buffer.write('  }');
  return buffer.toString();
}

/// Emits a no-arg constructor whose body materializes every `late final`
/// Effect field by reading it as a bare-identifier statement
/// (`<effectName>;`), in source-declaration order.
///
/// A plain Dart class has no `initState` lifecycle hook, but the same
/// `late final` Effect-materialization rule applies — without a synthesized
/// read, the Effect's factory constructor never runs and the autorun never
/// registers dependencies. Reading each Effect inside the generated
/// constructor body is the plain-class analogue of [emitInitState] for State
/// classes: the Effects activate at construction time, so a `Counter()`
/// instantiation is enough to start the autoruns.
///
/// Caller is responsible for only invoking this when
/// [effectNamesInDeclarationOrder] is non-empty — otherwise an empty
/// constructor is emitted, which is just noise relative to Dart's implicit
/// default constructor for a Signal-only class (see `rewritePlainClass`).
String emitConstructor(
  String className,
  List<String> effectNamesInDeclarationOrder,
) {
  final buffer = StringBuffer()..writeln('  $className() {');
  for (final name in effectNamesInDeclarationOrder) {
    buffer.writeln('    $name;');
  }
  buffer.write('  }');
  return buffer.toString();
}

/// Splices Effect-materialization reads (`<effectName>;`, in declaration
/// order) into the END of a user-declared plain-class constructor body,
/// after any user statements. The user's body is preserved verbatim — only
/// the trailing `}` is shifted to make room for the materialization lines.
///
/// Empty bodies (`;` / `{}`) are normalized to `{}` with the
/// materialization lines as the only contents. Initializer lists, factory
/// keywords, named/redirecting ctors, and `const` modifiers round-trip
/// verbatim; the merge only edits the BODY, not the header.
///
/// `const` is stripped from the lowered constructor: a plain class lowered
/// by this rewriter holds mutable `Signal<T>` / `Computed<T>` / `Effect`
/// fields, so `const ClassName()` is no longer compile-valid. Same rule as
/// the StatelessWidget → State split.
///
/// Throws [CodeGenerationError] for expression-body ctors (`=> …`) — Dart
/// constructors cannot have expression bodies, so this is a defense-in-
/// depth guard rather than an expected user path.
String mergeConstructor(
  ConstructorDeclaration ctor,
  List<String> effectNamesInDeclarationOrder,
  String source,
  String className,
) {
  final body = ctor.body;
  // Slice the constructor header verbatim, then attach a normalised body.
  // The header includes constructor name + parameter list + initializer
  // list (everything from `ctor.offset` up to the body's start).
  final headerEnd = body.offset;
  var header = source.substring(ctor.offset, headerEnd);
  // Strip a leading `const ` from the header — the class fields are no
  // longer const-eligible (they hold Signal/Computed/Effect instances).
  // Match `const` followed by whitespace; only the user-declared modifier
  // is stripped, not appearances elsewhere in the header (initializer
  // list literals etc.).
  header = header.replaceFirst(RegExp(r'^\s*const\s+'), '');
  final reads = effectNamesInDeclarationOrder
      .map((name) => '    $name;')
      .join('\n');
  if (body is EmptyFunctionBody) {
    // `Foo();` → `Foo() { ... }`.
    if (reads.isEmpty) return source.substring(ctor.offset, ctor.end);
    return '$header{\n$reads\n  }';
  }
  if (body is BlockFunctionBody) {
    final rbrace = body.block.rightBracket.offset;
    final bodyPrefix = source.substring(body.offset, rbrace);
    if (reads.isEmpty) {
      return '$header${source.substring(body.offset, body.end)}';
    }
    // Splice `\n<reads>\n` immediately before the closing `}`.
    return '$header$bodyPrefix\n$reads\n  }';
  }
  throw CodeGenerationError(
    'plain-class constructor must have a block body or no body for '
    'Effect-materialization merge',
    null,
    className,
  );
}
