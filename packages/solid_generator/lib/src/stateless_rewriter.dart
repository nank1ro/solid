import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/const_eligibility.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites a `StatelessWidget` class containing `@SolidState` fields as a
/// `StatefulWidget` + `State<X>` pair.
///
/// See SPEC Section 8.1. The emitted string is syntactically valid Dart but
/// is not guaranteed to be pretty-printed — run through `DartFormatter` before
/// writing.
RewriteResult rewriteStatelessWidget(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  String source,
) {
  final className = classDecl.name.lexeme;
  final stateClassName = '_${className}State';
  final ctorParams = _extractCtorParams(classDecl, source);
  final buildMethod = _findBuildMethod(classDecl);
  final reactiveFieldNames = solidFields.map((f) => f.fieldName).toSet();
  final buildMethodText = rewriteBuildMethod(
    buildMethod,
    reactiveFieldNames,
    source,
  );

  // Non-`@SolidState` fields stay on the public widget class (Flutter
  // convention: widget config fields are read from State via `widget.foo`).
  // Their compile-time-constness gates whether the public ctor gets `const`.
  final nonSolidFieldsText = _collectNonSolidFields(
    classDecl,
    reactiveFieldNames,
    source,
  );
  final constEligible = isConstEligible(classDecl, reactiveFieldNames);

  final widgetClass = _emitWidgetClass(
    className,
    stateClassName,
    ctorParams,
    nonSolidFieldsText,
    constEligible,
  );
  final stateClass = _emitStateClass(
    className,
    stateClassName,
    solidFields,
    buildMethodText,
  );

  return (
    text: '$widgetClass\n\n$stateClass\n',
    solidartNames: const <String>{'Signal', 'SignalBuilder'},
  );
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

/// Returns the `build` method declaration so it can be handed to the
/// reactive-rewrite pipeline. Throws [AnalysisError] if the class has no
/// `build` method (not a valid `StatelessWidget` under SPEC Section 8.1).
MethodDeclaration _findBuildMethod(ClassDeclaration classDecl) {
  for (final member in classDecl.members) {
    if (member is MethodDeclaration && member.name.lexeme == 'build') {
      return member;
    }
  }
  throw AnalysisError(
    'StatelessWidget has no build() method to preserve',
    null,
    classDecl.name.lexeme,
  );
}

/// Emits the public `StatefulWidget` half of the class split
/// (SPEC Section 8.1).
///
/// [constEligible] is the result of [isConstEligible] over the original
/// class's non-`@SolidState` fields (SPEC §14 item 7); when true, the public
/// constructor is prefixed with `const`. [nonSolidFieldsText] is the verbatim
/// source of every non-`@SolidState` field (already 2-space indented), spliced
/// between the constructor and `createState`. `DartFormatter` normalises
/// whitespace in the final output.
String _emitWidgetClass(
  String className,
  String stateClassName,
  String ctorParams,
  String nonSolidFieldsText,
  bool constEligible,
) {
  final constKw = constEligible ? 'const ' : '';
  final fieldsBlock = nonSolidFieldsText.isNotEmpty
      ? '\n\n$nonSolidFieldsText'
      : '';
  return '''
class $className extends StatefulWidget {
  $constKw$className$ctorParams;$fieldsBlock

  @override
  State<$className> createState() => $stateClassName();
}''';
}

/// Returns the verbatim source text of every non-`@SolidState` field in
/// [classDecl], joined with newlines and 2-space indented. Returns the empty
/// string when the class has no non-`@SolidState` fields (the common M1-01
/// case).
String _collectNonSolidFields(
  ClassDeclaration classDecl,
  Set<String> solidFieldNames,
  String source,
) {
  final buf = StringBuffer();
  for (final member in classDecl.members) {
    if (member is! FieldDeclaration) continue;
    final firstName = member.fields.variables.first.name.lexeme;
    if (solidFieldNames.contains(firstName)) continue;
    buf.writeln('  ${source.substring(member.offset, member.end)}');
  }
  return buf.toString().trimRight();
}

/// Emits the private `State<X>` half of the class split (SPEC Section 8.1).
///
/// `State<T>` has `dispose()` in its supertype chain, so the synthesized
/// `dispose()` is `@override` and ends with `super.dispose();` (SPEC §10).
String _emitStateClass(
  String className,
  String stateClassName,
  List<FieldModel> fields,
  String buildMethodText,
) {
  final signalFields = fields.map(emitSignalField).join('\n');
  final dispose = emitDispose(fields, inheritsDispose: true);

  return '''
class $stateClassName extends State<$className> {
$signalFields

$dispose

  $buildMethodText
}''';
}
