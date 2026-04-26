import 'package:solid_generator/src/field_model.dart';

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

/// Emits a `dispose()` method disposing every signal in reverse declaration
/// order (SPEC §10).
///
/// [inheritsDispose] is `true` when the owning class's supertype chain contains
/// a `dispose()` method (e.g. `State<T>`, `ChangeNotifier`); the emitted method
/// is then `@override` and ends with `super.dispose();`. For a plain class
/// whose supertype is `Object`, pass `false` — neither annotation nor
/// super-call is emitted (SPEC §8.3).
String emitDispose(
  List<FieldModel> fields, {
  required bool inheritsDispose,
}) {
  final buffer = StringBuffer();
  if (inheritsDispose) {
    buffer.writeln('  @override');
  }
  buffer.writeln('  void dispose() {');
  for (final f in fields.reversed) {
    buffer.writeln('    ${f.fieldName}.dispose();');
  }
  if (inheritsDispose) {
    buffer.writeln('    super.dispose();');
  }
  buffer.write('  }');
  return buffer.toString();
}
