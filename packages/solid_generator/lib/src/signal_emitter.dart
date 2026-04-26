import 'package:solid_generator/src/field_model.dart';

/// Shared signal-emission helpers used by every class-kind rewriter.
///
/// Centralising these here keeps the SPEC §4.1/4.2/4.3 signal construction
/// rules and the SPEC §10 dispose contract in a single place — rewriters for
/// `StatelessWidget`, plain classes, and (later) `State<X>` all share the same
/// output shape.

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

/// Emits a `dispose()` method disposing every signal in reverse declaration
/// order (SPEC Section 10).
///
/// [emitOverride] controls whether `@override` is prepended — `true` for
/// `State<X>` subclasses (which override `State.dispose`), `false` for plain
/// classes (no inherited `dispose` to override).
///
/// [emitSuperCall] controls whether `super.dispose();` is appended — `true`
/// when the supertype chain contains a `dispose()` method (e.g. `State<T>`,
/// `ChangeNotifier`), `false` for a plain class whose supertype chain is just
/// `Object` (SPEC §8.3 / §10).
String emitDispose(
  List<FieldModel> fields, {
  required bool emitOverride,
  required bool emitSuperCall,
}) {
  final buffer = StringBuffer();
  if (emitOverride) {
    buffer.writeln('  @override');
  }
  buffer.writeln('  void dispose() {');
  for (final f in fields.reversed) {
    buffer.writeln('    ${f.fieldName}.dispose();');
  }
  if (emitSuperCall) {
    buffer.writeln('    super.dispose();');
  }
  buffer.write('  }');
  return buffer.toString();
}
