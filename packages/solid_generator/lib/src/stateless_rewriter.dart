import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields as a
/// `StatefulWidget` + `State<X>` pair.
///
/// See SPEC Section 8.1. The emitted string is syntactically valid Dart but
/// is not guaranteed to be pretty-printed — run through `DartFormatter` before
/// writing.
String rewriteStatelessWidget(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final ctorParams = _extractCtorParams(classDecl, source);
  final buildMethodText = _extractBuildMethod(classDecl, source);

  final widgetClass = _emitWidgetClass(className, stateClassName, ctorParams);
  final stateClass = _emitStateClass(
    className,
    stateClassName,
    solidFields,
    buildMethodText,
  );

  return '$widgetClass\n\n$stateClass\n';
}

/// Extracts the parenthesized parameter list of the class's unnamed
/// constructor, e.g. `({super.key})`. Returns `()` if no constructor is
/// declared (the default constructor is implicit).
String _extractCtorParams(ClassDeclaration classDecl, String source) {
  for (final member in classDecl.members) {
    if (member is ConstructorDeclaration && member.name == null) {
      final params = member.parameters;
      return source.substring(params.offset, params.end);
    }
  }
  return '()';
}

/// Extracts the full source text of the `build` method, including its
/// `@override` annotation, return type, parameters, and body.
String _extractBuildMethod(ClassDeclaration classDecl, String source) {
  for (final member in classDecl.members) {
    if (member is MethodDeclaration && member.name.lexeme == 'build') {
      return source.substring(member.offset, member.end);
    }
  }
  final className = classDecl.name.lexeme;
  throw AnalysisError(
    'StatelessWidget has no build() method to preserve',
    null,
    className,
  );
}

/// Emits the public `StatefulWidget` half of the class split
/// (SPEC Section 8.1).
//
// TODO(M1-13): `const` is emitted unconditionally here. SPEC §8.1 says "gains
// `const` where safe (all fields final and literal)". For M1-01 the single
// `int counter = 0;` case is always const-eligible because the @SolidState
// field moves off the widget class entirely. M1-13 introduces the general
// const-eligibility check based on remaining non-`@SolidState` fields.
String _emitWidgetClass(
  String className,
  String stateClassName,
  String ctorParams,
) {
  return '''
class $className extends StatefulWidget {
  const $className$ctorParams;

  @override
  State<$className> createState() => $stateClassName();
}''';
}

/// Emits the private `State<X>` half of the class split (SPEC Section 8.1).
String _emitStateClass(
  String className,
  String stateClassName,
  List<FieldModel> fields,
  String buildMethodText,
) {
  final signalFields = fields.map(_emitSignalField).join('\n');
  final dispose = _emitDispose(fields);

  return '''
class $stateClassName extends State<$className> {
$signalFields

$dispose

  $buildMethodText
}''';
}

/// Emits one `[late ]final <name> = Signal<T>(…, name: '<debug>');` line per
/// SPEC Section 4.1. When the source field is `late` with no initializer,
/// emits `Signal<T>.lazy(name: '<debug>')` per SPEC Section 4.2 — reading
/// `.value` before the first write throws `StateError`, matching Dart's own
/// `late` semantics. The `late` modifier is preserved verbatim on the Dart
/// field so that `Signal` construction itself is deferred to first access.
String _emitSignalField(FieldModel f) {
  final debugName = f.annotationName ?? f.fieldName;
  final lateKw = f.isLate ? 'late ' : '';
  final ctor = f.initializerText.isNotEmpty
      ? "Signal<${f.typeText}>(${f.initializerText}, name: '$debugName')"
      : "Signal<${f.typeText}>.lazy(name: '$debugName')";
  return '  ${lateKw}final ${f.fieldName} = $ctor;';
}

/// Emits the `dispose()` method disposing every signal in reverse declaration
/// order (SPEC Section 10). `super.dispose()` is always emitted here because
/// `State<T>` has `dispose()` in its supertype chain.
String _emitDispose(List<FieldModel> fields) {
  final buffer = StringBuffer()
    ..writeln('  @override')
    ..writeln('  void dispose() {');
  for (final f in fields.reversed) {
    buffer.writeln('    ${f.fieldName}.dispose();');
  }
  buffer
    ..writeln('    super.dispose();')
    ..write('  }');
  return buffer.toString();
}
