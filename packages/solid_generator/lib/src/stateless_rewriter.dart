import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/signal_emitter.dart';
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
  final buildMethod = _findBuildMethod(classDecl);
  final reactiveFieldNames = solidFields.map((f) => f.fieldName).toSet();
  final buildMethodText = rewriteBuildMethod(
    buildMethod,
    reactiveFieldNames,
    source,
  );

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
