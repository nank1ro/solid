import 'package:analyzer/dart/ast/ast.dart';

import 'result.dart';
import 'transformation_error.dart';
import 'ast_models.dart';

/// Pure function to parse @SolidState annotation from a field declaration.
/// Returns Result to avoid throwing exceptions (functional error handling).
Result<AnnotationInfo, AnnotationParseError> parseSolidStateAnnotation(
  FieldDeclaration field,
) {
  try {
    // Extract annotations immutably
    final annotations = List<Annotation>.unmodifiable(field.metadata);

    // Find @SolidState annotation
    final stateAnnotation = annotations.where((annotation) {
      final name = annotation.name.name;
      return name == 'SolidState';
    }).firstOrNull;

    if (stateAnnotation == null) {
      return const Failure(
        AnnotationParseError(
          'No @SolidState annotation found',
          null,
          'SolidState',
        ),
      );
    }

    // Parse annotation arguments immutably
    String? customName;
    final arguments = stateAnnotation.arguments;
    if (arguments != null && arguments.arguments.isNotEmpty) {
      for (final arg in arguments.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'name') {
          if (arg.expression is StringLiteral) {
            customName = (arg.expression as StringLiteral).stringValue;
          }
        }
      }
    }

    return Success(AnnotationInfo(name: 'SolidState', customName: customName));
  } catch (e) {
    return Failure(
      AnnotationParseError(
        'Failed to parse @SolidState annotation: $e',
        _getLocationString(field),
        'SolidState',
      ),
    );
  }
}

/// Pure function to parse @SolidState annotation from a getter method.
/// Handles the case where @SolidState is used on getters for Computed.
Result<AnnotationInfo, AnnotationParseError>
parseSolidStateAnnotationFromGetter(MethodDeclaration getter) {
  try {
    // Extract annotations immutably
    final annotations = List<Annotation>.unmodifiable(getter.metadata);

    // Find @SolidState annotation
    final stateAnnotation = annotations.where((annotation) {
      final name = annotation.name.name;
      return name == 'SolidState';
    }).firstOrNull;

    if (stateAnnotation == null) {
      return const Failure(
        AnnotationParseError(
          'No @SolidState annotation found',
          null,
          'SolidState',
        ),
      );
    }

    // Parse annotation arguments immutably
    String? customName;
    final arguments = stateAnnotation.arguments;
    if (arguments != null && arguments.arguments.isNotEmpty) {
      for (final arg in arguments.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'name') {
          if (arg.expression is StringLiteral) {
            customName = (arg.expression as StringLiteral).stringValue;
          }
        }
      }
    }

    return Success(AnnotationInfo(name: 'SolidState', customName: customName));
  } catch (e) {
    return Failure(
      AnnotationParseError(
        'Failed to parse @SolidState annotation from getter: $e',
        _getLocationString(getter),
        'SolidState',
      ),
    );
  }
}

/// Pure function to parse @SolidEffect annotation from a method.
Result<AnnotationInfo, AnnotationParseError> parseSolidEffectAnnotation(
  MethodDeclaration method,
) {
  try {
    // Extract annotations immutably
    final annotations = List<Annotation>.unmodifiable(method.metadata);

    // Find @SolidEffect annotation
    final effectAnnotation = annotations.where((annotation) {
      final name = annotation.name.name;
      return name == 'SolidEffect';
    }).firstOrNull;

    if (effectAnnotation == null) {
      return const Failure(
        AnnotationParseError(
          'No @SolidEffect annotation found',
          null,
          'SolidEffect',
        ),
      );
    }

    // @SolidEffect currently has no parameters
    return const Success(AnnotationInfo(name: 'SolidEffect'));
  } catch (e) {
    return Failure(
      AnnotationParseError(
        'Failed to parse @SolidEffect annotation: $e',
        _getLocationString(method),
        'SolidEffect',
      ),
    );
  }
}

/// Pure function to parse @SolidQuery annotation from a method.
Result<AnnotationInfo, AnnotationParseError> parseQueryAnnotation(
  MethodDeclaration method,
) {
  try {
    // Extract annotations immutably
    final annotations = List<Annotation>.unmodifiable(method.metadata);

    // Find @SolidQuery annotation
    final queryAnnotation = annotations.where((annotation) {
      final name = annotation.name.name;
      return name == 'SolidQuery';
    }).firstOrNull;

    if (queryAnnotation == null) {
      return const Failure(
        AnnotationParseError(
          'No @SolidQuery annotation found',
          null,
          'SolidQuery',
        ),
      );
    }

    // Parse annotation arguments immutably
    String? customName;
    String? debounceExpression;
    bool? useRefreshing;
    final arguments = queryAnnotation.arguments;
    if (arguments != null && arguments.arguments.isNotEmpty) {
      for (final arg in arguments.arguments) {
        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          if (paramName == 'name' && arg.expression is StringLiteral) {
            customName = (arg.expression as StringLiteral).stringValue;
          } else if (paramName == 'debounce') {
            // Store the original Duration expression as string
            debounceExpression = arg.expression.toSource();
          } else if (paramName == 'useRefreshing' &&
              arg.expression is BooleanLiteral) {
            useRefreshing = (arg.expression as BooleanLiteral).value;
          }
        }
      }
    }

    return Success(
      AnnotationInfo(
        name: 'SolidQuery',
        customName: customName,
        debounceExpression: debounceExpression,
        useRefreshing: useRefreshing,
      ),
    );
  } catch (e) {
    return Failure(
      AnnotationParseError(
        'Failed to parse @SolidQuery annotation: $e',
        _getLocationString(method),
        'SolidQuery',
      ),
    );
  }
}

/// Pure function to parse @Environment annotation from a field.
Result<AnnotationInfo, AnnotationParseError> parseEnvironmentAnnotation(
  FieldDeclaration field,
) {
  try {
    // Extract annotations immutably
    final annotations = List<Annotation>.unmodifiable(field.metadata);

    // Find @Environment annotation
    final environmentAnnotation = annotations.where((annotation) {
      final name = annotation.name.name;
      return name == 'SolidEnvironment';
    }).firstOrNull;

    if (environmentAnnotation == null) {
      return const Failure(
        AnnotationParseError(
          'No @SolidEnvironment annotation found',
          null,
          'SolidEnvironment',
        ),
      );
    }

    // @Environment currently has no parameters
    return const Success(AnnotationInfo(name: 'SolidEnvironment'));
  } catch (e) {
    return Failure(
      AnnotationParseError(
        'Failed to parse @SolidEnvironment annotation: $e',
        _getLocationString(field),
        'SolidEnvironment',
      ),
    );
  }
}

/// Pure helper function to extract location string from AST node
String _getLocationString(AstNode node) {
  try {
    final source = node.root.toSource();
    final offset = node.offset;
    final lines = source.substring(0, offset).split('\n');
    return 'line ${lines.length}:${lines.last.length + 1}';
  } catch (e) {
    return 'unknown location';
  }
}
