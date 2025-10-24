import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'result.dart';
import 'transformation_error.dart';
import 'annotation_parser.dart';
import 'field_analyzer.dart';
import 'code_generator.dart';

/// Abstract base class for functional transformers.
/// Each transformer handles exactly one AST transformation type.
abstract class FunctionalTransformer<TInput, TOutput> {
  /// Pure function - no side effects
  Result<TOutput, TransformationError> transform(TInput input);

  /// Validation as pure function
  bool canTransform(TInput input);

  /// Immutable dependency extraction
  List<String> extractDependencies(TInput input);
}

/// Functional transformer for @SolidState fields -> Signal declarations.
/// Follows single responsibility principle and pure function requirements.
class SolidStateTransformer
    extends FunctionalTransformer<FieldDeclaration, String> {
  SolidStateTransformer();

  @override
  Result<String, TransformationError> transform(FieldDeclaration field) {
    // Functional pipeline with immutable data flow
    return parseSolidStateAnnotation(field)
        .mapError<TransformationError>((error) => error)
        .flatMap<String>(
          (annotation) => extractFieldInfo(field)
              .mapError<TransformationError>((error) => error)
              .map<String>(
                (fieldInfo) => generateSignalDeclaration(fieldInfo, annotation),
              ),
        );
  }

  @override
  bool canTransform(FieldDeclaration field) {
    // Pure validation function
    try {
      final annotations = field.metadata;
      return annotations.any(
        (annotation) => annotation.name.name == 'SolidState',
      );
    } catch (e) {
      return false;
    }
  }

  @override
  List<String> extractDependencies(FieldDeclaration field) {
    // Fields don't have dependencies (unlike getters/methods)
    return const [];
  }
}

/// Functional transformer for @SolidState getters -> Computed declarations.
/// Handles getters with reactive dependencies.
class SolidComputedTransformer
    extends FunctionalTransformer<MethodDeclaration, String> {
  SolidComputedTransformer();

  @override
  Result<String, TransformationError> transform(MethodDeclaration getter) {
    // Functional pipeline with immutable data flow
    return parseSolidStateAnnotationFromGetter(getter)
        .mapError<TransformationError>((error) => error)
        .flatMap<String>(
          (annotation) => extractGetterInfo(getter)
              .mapError<TransformationError>((error) => error)
              .map<String>(
                (getterInfo) => generateComputedDeclaration(
                  getterInfo,
                  annotation,
                  extractDependencies(getter),
                ),
              ),
        );
  }

  @override
  bool canTransform(MethodDeclaration getter) {
    // Pure validation function
    try {
      if (!getter.isGetter) return false;
      final annotations = getter.metadata;
      return annotations.any(
        (annotation) => annotation.name.name == 'SolidState',
      );
    } catch (e) {
      return false;
    }
  }

  @override
  List<String> extractDependencies(MethodDeclaration getter) {
    // Extract reactive variable dependencies from getter expression using AST visitor
    try {
      final body = getter.body;

      if (body is ExpressionFunctionBody) {
        return _extractReactiveDependencies(body.expression);
      } else if (body is BlockFunctionBody) {
        return _extractReactiveDependencies(body.block);
      }

      return const [];
    } catch (e) {
      return const [];
    }
  }
}

/// Functional transformer for @SolidEffect methods -> Effect declarations.
class SolidEffectTransformer
    extends FunctionalTransformer<MethodDeclaration, String> {
  SolidEffectTransformer();

  @override
  Result<String, TransformationError> transform(MethodDeclaration method) {
    // Functional pipeline with immutable data flow
    return parseSolidEffectAnnotation(method)
        .mapError<TransformationError>((error) => error)
        .flatMap<String>(
          (_) => extractMethodInfo(method)
              .mapError<TransformationError>((error) => error)
              .map<String>((methodInfo) {
                final dependencies = extractDependencies(method);
                final transformedBody = _transformEffectBody(
                  methodInfo.body,
                  dependencies,
                );
                return generateEffectDeclaration(methodInfo, transformedBody);
              }),
        );
  }

  @override
  bool canTransform(MethodDeclaration method) {
    // Pure validation function
    try {
      final annotations = method.metadata;
      return annotations.any(
        (annotation) => annotation.name.name == 'SolidEffect',
      );
    } catch (e) {
      return false;
    }
  }

  @override
  List<String> extractDependencies(MethodDeclaration method) {
    // Extract reactive variable dependencies from method body using AST visitor
    try {
      final body = method.body;

      if (body is BlockFunctionBody) {
        return _extractReactiveDependencies(body.block);
      } else if (body is ExpressionFunctionBody) {
        return _extractReactiveDependencies(body.expression);
      }

      return const [];
    } catch (e) {
      return const [];
    }
  }

  String _transformEffectBody(String body, List<String> dependencies) {
    String transformedBody = body;

    // Transform reactive variable access to use .value
    for (final dependency in dependencies) {
      // Handle string interpolation first - transform $dependency to ${dependency.value}
      final interpolationPattern = RegExp(
        r'\$' + dependency + r'(?!\.value)(?!\w)',
      );
      transformedBody = transformedBody.replaceAll(
        interpolationPattern,
        '\${$dependency.value}',
      );

      // Handle other variable access patterns (not in string interpolation)
      final variablePattern = RegExp(
        r'(?<!\$)\b' + dependency + r'\b(?!\.value)',
      );
      transformedBody = transformedBody.replaceAll(
        variablePattern,
        '$dependency.value',
      );
    }

    return transformedBody;
  }
}

/// Functional transformer for @SolidQuery methods -> Resource declarations.
class SolidQueryTransformer
    extends FunctionalTransformer<MethodDeclaration, String> {
  SolidQueryTransformer();

  @override
  Result<String, TransformationError> transform(MethodDeclaration method) {
    // Functional pipeline with immutable data flow
    return parseQueryAnnotation(method)
        .mapError<TransformationError>((error) => error)
        .flatMap<String>(
          (annotation) => extractMethodInfo(method)
              .mapError<TransformationError>((error) => error)
              .map<String>((methodInfo) {
                final dependencies = extractDependencies(method);
                return generateResourceDeclaration(
                  methodInfo,
                  annotation,
                  dependencies,
                );
              }),
        );
  }

  @override
  bool canTransform(MethodDeclaration method) {
    // Pure validation function
    try {
      final annotations = method.metadata;
      return annotations.any(
        (annotation) => annotation.name.name == 'SolidQuery',
      );
    } catch (e) {
      return false;
    }
  }

  @override
  List<String> extractDependencies(MethodDeclaration method) {
    // Extract reactive variable dependencies from method body using AST visitor
    try {
      final body = method.body;

      if (body is BlockFunctionBody) {
        return _extractReactiveDependencies(body.block);
      } else if (body is ExpressionFunctionBody) {
        return _extractReactiveDependencies(body.expression);
      }

      return const [];
    } catch (e) {
      return const [];
    }
  }
}

/// Pure helper function to extract reactive dependencies from AST node.
/// Uses proper AST analysis instead of regex patterns.
List<String> _extractReactiveDependencies(AstNode node) {
  final visitor = _ReactiveVariableVisitor();
  node.accept(visitor);
  return List.unmodifiable(visitor.dependencies);
}

/// Functional transformer for @Environment fields -> context.read\<T>() calls.
/// Handles dependency injection from environment context.
class EnvironmentTransformer
    extends FunctionalTransformer<FieldDeclaration, String> {
  EnvironmentTransformer();

  @override
  Result<String, TransformationError> transform(FieldDeclaration field) {
    // Functional pipeline with immutable data flow
    return parseEnvironmentAnnotation(field)
        .mapError<TransformationError>((error) => error)
        .flatMap<String>(
          (annotation) => extractFieldInfo(field)
              .mapError<TransformationError>((error) => error)
              .map<String>(
                (fieldInfo) =>
                    generateEnvironmentDeclaration(fieldInfo, annotation),
              ),
        );
  }

  @override
  bool canTransform(FieldDeclaration field) {
    // Pure validation function
    try {
      final annotations = field.metadata;
      return annotations.any(
        (annotation) => annotation.name.name == 'SolidEnvironment',
      );
    } catch (e) {
      return false;
    }
  }

  @override
  List<String> extractDependencies(FieldDeclaration field) {
    // Environment fields don't have reactive dependencies (they come from context)
    return const [];
  }
}

/// AST visitor to extract potential reactive variable dependencies.
/// Looks for SimpleIdentifier nodes that could be field references.
class _ReactiveVariableVisitor extends RecursiveAstVisitor<void> {
  final Set<String> _dependencies = <String>{};

  List<String> get dependencies => _dependencies.toList();

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Only consider identifiers that could be field references
    // Exclude:
    // - Method calls (parent is MethodInvocation and this is the methodName)
    // - Property access (parent is PropertyAccess and this is the propertyName)
    // - Constructor names, type names, etc.

    final parent = node.parent;

    // Skip if this is a method name in a method invocation
    if (parent is MethodInvocation && parent.methodName == node) {
      return;
    }

    // Skip if this is a property name in property access
    if (parent is PropertyAccess && parent.propertyName == node) {
      return;
    }

    // Skip if this is the target of a property access (but consider the base object)
    // For example: in "object.property", we want "object" but not "property"
    if (parent is PrefixedIdentifier && parent.identifier == node) {
      return;
    }

    // Skip if this is a named expression label
    if (parent is NamedExpression && parent.name.label == node) {
      return;
    }

    // Skip if this is a type annotation
    if (parent is NamedType) {
      return;
    }

    // Skip keywords and special identifiers
    if (node.name == 'this' ||
        node.name == 'super' ||
        node.name == 'null' ||
        node.name == 'true' ||
        node.name == 'false') {
      return;
    }

    // Skip constructor names and type references
    if (parent is ConstructorName ||
        parent is TypeArgumentList ||
        parent is ExtendsClause ||
        parent is ImplementsClause ||
        parent is WithClause) {
      return;
    }

    // Skip import prefixes and library names
    if (parent is ImportDirective ||
        parent is LibraryDirective ||
        parent is PartDirective) {
      return;
    }

    // Skip named parameters in constructors and method calls
    if (parent is Label && parent.parent is NamedExpression) {
      return;
    }

    // Skip function parameters - walk up the AST to check if this identifier is a parameter
    AstNode? current = node;
    while (current != null) {
      if (current is FunctionExpression) {
        final params = current.parameters?.parameters ?? [];
        if (params.any(
          (param) =>
              (param is SimpleFormalParameter &&
                  param.name?.lexeme == node.name) ||
              (param is DefaultFormalParameter &&
                  param.parameter.name?.lexeme == node.name),
        )) {
          return; // This is a function parameter, skip it
        }
      }
      current = current.parent;
    }

    // Skip class names and built-in types
    final builtInTypes = {
      'int',
      'double',
      'String',
      'bool',
      'List',
      'Map',
      'Set',
      'Future',
      'Stream',
      'Duration',
      'DateTime',
    };
    if (builtInTypes.contains(node.name)) {
      return;
    }

    // Skip common Flutter/Dart classes that are not fields
    final commonClasses = {
      'Widget',
      'State',
      'StatefulWidget',
      'StatelessWidget',
      'BuildContext',
      'MaterialApp',
      'Scaffold',
      'AppBar',
      'Text',
      'ElevatedButton',
      'CircularProgressIndicator',
      'SizedBox',
      'Column',
      'Row',
      'Center',
      'Container',
    };
    if (commonClasses.contains(node.name)) {
      return;
    }

    // This could be a field reference - add it as a potential dependency
    _dependencies.add(node.name);

    super.visitSimpleIdentifier(node);
  }
}
