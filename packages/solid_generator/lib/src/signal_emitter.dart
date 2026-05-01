import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Shared signal-emission helpers used by every class-kind rewriter.

/// Emits one `[late ]final <name> = Signal<T>(…, name: '<debug>');` line.
///
/// Three cases, in priority order:
///
/// 1. **Has initializer** (SPEC Section 4.1) →
///    `Signal<T>(<init>, name: '<debug>')`. The `late` modifier (if any)
///    is preserved verbatim so that `Signal` construction itself is deferred
///    to first access.
/// 2. **No initializer, nullable type** (SPEC Section 4.3) →
///    `Signal<T?>(null, name: '<debug>')`. No `late` needed because `null`
///    is a valid default.
/// 3. **No initializer, non-nullable type** (SPEC Section 4.2) →
///    `Signal<T>.lazy(name: '<debug>')`. The source field must have been
///    declared `late` (the only way Dart accepts a non-nullable field with
///    no initializer); the modifier is preserved on the emitted field so
///    reads before the first write throw `StateError`, matching Dart's own
///    `late` semantics.
String emitSignalField(FieldModel f) {
  final debugName = f.annotationName ?? f.fieldName;
  final lateKw = f.isLate ? 'late ' : '';
  final String ctor;
  if (f.initializerText.isNotEmpty) {
    ctor = "Signal<${f.typeText}>(${f.initializerText}, name: '$debugName')";
  } else if (f.isNullable) {
    ctor = "Signal<${f.typeText}>(null, name: '$debugName')";
  } else {
    ctor = "Signal<${f.typeText}>.lazy(name: '$debugName')";
  }
  return '  ${lateKw}final ${f.fieldName} = $ctor;';
}

/// Emits one `late final <name> = Computed<T>(<closure>, name: '<debug>');`
/// line per SPEC §4.5 (expression body) or §4.6 (block body).
///
/// The result is always `late final` because a `Computed` references other
/// `final` instance fields whose initialization order is not guaranteed
/// (SPEC §4.5 last bullet). The body text in [g] has already had the
/// SPEC §5.1 `.value` rewrite applied by `readSolidStateGetter`, so the
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

/// Emits one `late final <name> = Effect(<closure>, name: '<debug>');` line
/// per SPEC §4.7. Mirrors [emitComputedField] (same closure shape, same
/// `late final` rationale, same body-text contract); the only differences
/// are the absent type parameter and the `Effect` ctor.
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
/// (Stream form) line per SPEC §4.8. Mirrors [emitEffectField]'s closure-shape
/// contract — same `late final` rationale, same body-text contract — but
/// adds:
///
/// * a type argument `Resource<T>` peeled from the source `Future<T>` /
///   `Stream<T>` return type (carried on [QueryModel.innerTypeText]),
/// * the upstream `.stream` named constructor when [QueryModel.isStream] is
///   true (its fetcher signature is `Stream<T> Function()`, not the default
///   `Future<T> Function()`),
/// * the source body keyword spliced verbatim into the closure signature
///   ([QueryModel.bodyKeyword] is one of `'async'`, `'async*'`, or `''`), and
/// * a public field name (no underscore prefix) — SPEC §4.8 rule 1 specifies
///   a single emitted declaration per query.
///
/// The Resource field always joins the unified ordered dispose list managed
/// by [emitDispose] (SPEC §4.8 rule 11). Resources are NEVER materialized in
/// `initState()` / the synthesized constructor — the lazy `late final`
/// initializer fires on first read at the first reactive call site
/// (SPEC §4.8 rule 10 / §14 item 4).
String emitResourceField(QueryModel q) {
  final debugName = q.annotationName ?? q.methodName;
  final asyncKw = q.bodyKeyword.isEmpty ? '' : '${q.bodyKeyword} ';
  final closure = q.isBlockBody
      ? '() $asyncKw${q.bodyText}'
      : '() $asyncKw=> ${q.bodyText}';
  final ctorName = q.isStream
      ? 'Resource<${q.innerTypeText}>.stream'
      : 'Resource<${q.innerTypeText}>';
  // SPEC §4.8 rule 5: a single-Signal Computed wrapper would be a no-op, so
  // the one-name case passes the Signal/Computed directly as `source:`.
  // SPEC §4.8 rule 9: `useRefreshing: true` is the upstream default and is
  // omitted from emitted output to keep generated lines short.
  final source = switch (q.trackedSignalNames) {
    [] => null,
    [final only] => only,
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
/// `@SolidEnvironment` field (SPEC §4.9). Env fields are NEVER added to the
/// dispose-name list (SPEC §10 — the providing `Provider<T>` owns disposal)
/// and NEVER materialized in `initState` (SPEC §4.9 rule 2 — they're lazy).
String emitEnvironmentField(EnvironmentModel e) {
  return '  late final ${e.fieldName} = context.read<${e.typeText}>();';
}

/// Emits the synthesized Record-Computed source field for an `@SolidQuery`
/// method whose body reads two or more `@SolidState` field/getter
/// identifiers (SPEC §3.5 / §4.8 rule 5). Shape:
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
/// type text — the SPEC requires explicit type annotations on `@SolidState`
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
) {
  if (!q.needsSourceComputed) return null;
  final names = q.trackedSignalNames;
  final types = names.map((n) {
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
  final tupleType = '(${types.join(', ')})';
  final tupleExpr = '(${names.map((n) => '$n.value').join(', ')})';
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
void emitQueryFields(
  QueryModel q,
  Map<String, String> reactiveTypeTexts,
  List<String> output,
  List<String> disposeNames,
) {
  final sourceField = emitQuerySourceField(q, reactiveTypeTexts);
  if (sourceField != null) {
    output.add(sourceField);
    disposeNames.add(q.sourceFieldName);
  }
  output.add(emitResourceField(q));
  disposeNames.add(q.methodName);
}

/// Emits a `dispose()` method disposing every name in
/// [disposeNamesInDeclarationOrder] in **reverse declaration order** (SPEC
/// §10).
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
/// `solid_annotations` marker interface that lowered plain classes implement
/// per SPEC §10).
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
/// untouched (SPEC §10 / §14 item 4).
///
/// Shared by `state_class_rewriter` and `plain_class_rewriter` so the
/// dispose-body merge contract stays single-sourced. The user's source body
/// — including any `@override` annotation, return type, and existing
/// statements (e.g. `unawaited(_subscription.cancel());`) — is sliced
/// verbatim from `source.substring(method.offset, method.end)` and a single
/// `\n<disposals>` block is spliced immediately after the body's opening
/// brace. When the user's source `dispose()` lacks `@override`, the
/// generator prepends one: the merged dispose always overrides — either
/// `Disposable.dispose()` (plain class — SPEC §10 marker rule) or the
/// supertype's `dispose()` (`State<X>` — SPEC §14 item 4) — so the lowered
/// output is lint-clean against `annotate_overrides`.
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
  // doc comment for the SPEC contract.
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
/// SPEC §4.7: in Dart, `late final field = expr` defers the initializer until
/// the field is first read. Without this synthesized read, the Effect's
/// factory constructor — and its `effect.run()` autorun, which registers
/// reactive dependencies — would never fire during the widget's mounted
/// lifetime. The `dispose()` body's `<effectName>.dispose()` call is the
/// first read, by which point signal mutations have already happened.
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
/// SPEC §4.7 + §8.3: a plain Dart class has no `initState` lifecycle hook,
/// but the same `late final` Effect-materialization rule applies — without a
/// synthesized read, the Effect's factory constructor never runs and the
/// autorun never registers dependencies. Reading each Effect inside the
/// generated constructor body is the plain-class analogue of
/// [emitInitState] for State classes: the Effects activate at construction
/// time, so a `Counter()` instantiation is enough to start the autoruns.
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
