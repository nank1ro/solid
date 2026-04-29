import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';

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
/// [inheritsDispose] is `true` when the owning class's supertype chain
/// contains a `dispose()` method (e.g. `State<T>`, `ChangeNotifier`); the
/// emitted method is then `@override` and ends with `super.dispose();`. For
/// a plain class whose supertype is `Object`, pass `false` — neither
/// annotation nor super-call is emitted (SPEC §8.3).
String emitDispose(
  List<String> disposeNamesInDeclarationOrder, {
  required bool inheritsDispose,
}) {
  final buffer = StringBuffer();
  if (inheritsDispose) {
    buffer.writeln('  @override');
  }
  buffer.writeln('  void dispose() {');
  for (final name in disposeNamesInDeclarationOrder.reversed) {
    buffer.writeln('    $name.dispose();');
  }
  if (inheritsDispose) {
    buffer.writeln('    super.dispose();');
  }
  buffer.write('  }');
  return buffer.toString();
}

/// Emits an `initState()` method that materializes every `late final` Effect
/// field by reading it through a wildcard discard (`final _ = <effectName>;`),
/// in source-declaration order.
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
/// initial signal values and subscribes to subsequent changes. The Dart 3
/// wildcard pattern `final _ = <name>;` is used (rather than a bare
/// `<name>;` statement) so consumer apps that enable the
/// `unnecessary_statements` lint do not flag generator output.
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
    buffer.writeln('    final _ = $name;');
  }
  buffer.write('  }');
  return buffer.toString();
}
