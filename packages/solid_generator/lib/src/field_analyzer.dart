import 'package:analyzer/dart/ast/ast.dart';

import 'result.dart';
import 'transformation_error.dart';
import 'ast_models.dart';

/// Pure function to extract field information from a FieldDeclaration.
/// Returns immutable FieldInfo without modifying the input AST.
Result<FieldInfo, AnalysisError> extractFieldInfo(FieldDeclaration field) {
  try {
    // Immutably extract field information
    final fields = field.fields;
    final variables = List<VariableDeclaration>.unmodifiable(fields.variables);

    if (variables.isEmpty) {
      return Failure(
        AnalysisError(
          'Field declaration has no variables',
          _getLocationString(field),
          'unknown',
        ),
      );
    }

    // Take the first variable (fields can declare multiple variables)
    final variable = variables.first;
    final variableName = variable.name.lexeme;

    // Extract type information immutably
    final typeAnnotation = fields.type;
    String typeString;
    bool isNullable = false;

    if (typeAnnotation != null) {
      typeString = typeAnnotation.toSource();
      // Check for nullable type (ends with ?)
      isNullable = typeString.endsWith('?');
    } else {
      // Type inference case - we'll need to analyze the initializer
      typeString = 'dynamic'; // Fallback
    }

    // Extract initialization value immutably
    String? initialValue;
    final initializer = variable.initializer;
    if (initializer != null) {
      initialValue = initializer.toSource();
    }

    // Extract modifiers immutably
    final keyword = field.fields.keyword;
    final isFinal = keyword?.lexeme == 'final';
    final isConst = keyword?.lexeme == 'const';

    return Success(
      FieldInfo(
        name: variableName,
        type: typeString,
        initialValue: initialValue,
        isNullable: isNullable,
        isFinal: isFinal,
        isConst: isConst,
        location: _getLocationString(field),
      ),
    );
  } catch (e) {
    return Failure(
      AnalysisError(
        'Failed to extract field information: $e',
        _getLocationString(field),
        'field',
      ),
    );
  }
}

/// Pure function to extract getter information from a MethodDeclaration.
/// Returns immutable GetterInfo without modifying the input AST.
Result<GetterInfo, AnalysisError> extractGetterInfo(MethodDeclaration getter) {
  try {
    if (!getter.isGetter) {
      return Failure(
        AnalysisError(
          'Method is not a getter',
          _getLocationString(getter),
          getter.name.lexeme,
        ),
      );
    }

    final getterName = getter.name.lexeme;

    // Extract return type immutably
    final returnTypeAnnotation = getter.returnType;
    String returnTypeString;
    bool isNullable = false;

    if (returnTypeAnnotation != null) {
      returnTypeString = returnTypeAnnotation.toSource();
      isNullable = returnTypeString.endsWith('?');
    } else {
      returnTypeString = 'dynamic'; // Fallback for type inference
    }

    // Extract getter body expression immutably
    String expression = '';
    final body = getter.body;
    if (body is ExpressionFunctionBody) {
      expression = body.expression.toSource();
    } else if (body is BlockFunctionBody) {
      // For block bodies, we need to extract the return statement
      final statements = body.block.statements;
      if (statements.isNotEmpty) {
        final lastStatement = statements.last;
        if (lastStatement is ReturnStatement &&
            lastStatement.expression != null) {
          expression = lastStatement.expression!.toSource();
        }
      }
    }

    return Success(
      GetterInfo(
        name: getterName,
        returnType: returnTypeString,
        expression: expression,
        isNullable: isNullable,
        location: _getLocationString(getter),
      ),
    );
  } catch (e) {
    return Failure(
      AnalysisError(
        'Failed to extract getter information: $e',
        _getLocationString(getter),
        getter.name.lexeme,
      ),
    );
  }
}

/// Pure function to extract method information from a MethodDeclaration.
/// Returns immutable MethodInfo without modifying the input AST.
Result<MethodInfo, AnalysisError> extractMethodInfo(MethodDeclaration method) {
  try {
    final methodName = method.name.lexeme;

    // Extract return type immutably
    final returnTypeAnnotation = method.returnType;
    String returnTypeString;
    if (returnTypeAnnotation != null) {
      returnTypeString = returnTypeAnnotation.toSource();
    } else {
      returnTypeString = 'void'; // Default for methods
    }

    // Extract method body immutably
    String bodyString = '';
    final body = method.body;
    if (body is BlockFunctionBody) {
      bodyString = body.block.toSource();
    } else if (body is ExpressionFunctionBody) {
      bodyString = '=> ${body.expression.toSource()};';
    }

    // Extract parameters immutably
    final parameterList = method.parameters;
    final parameters = <ParameterInfo>[];
    if (parameterList != null) {
      for (final param in parameterList.parameters) {
        final paramInfo = _extractParameterInfo(param);
        parameters.add(paramInfo);
      }
    }

    // Check if method is async
    final isAsync = method.body is BlockFunctionBody
        ? (method.body as BlockFunctionBody).keyword?.lexeme == 'async'
        : false;

    return Success(
      MethodInfo(
        name: methodName,
        returnType: returnTypeString,
        body: bodyString,
        parameters: List.unmodifiable(parameters),
        isAsync: isAsync,
        location: _getLocationString(method),
      ),
    );
  } catch (e) {
    return Failure(
      AnalysisError(
        'Failed to extract method information: $e',
        _getLocationString(method),
        method.name.lexeme,
      ),
    );
  }
}

/// Pure helper function to extract parameter information
ParameterInfo _extractParameterInfo(FormalParameter param) {
  String name = '';
  String type = 'dynamic';
  bool isOptional = false;
  bool isNamed = false;
  String? defaultValue;

  if (param is SimpleFormalParameter) {
    name = param.name?.lexeme ?? '';
    if (param.type != null) {
      type = param.type!.toSource();
    }
  } else if (param is DefaultFormalParameter) {
    final parameter = param.parameter;
    if (parameter is SimpleFormalParameter) {
      name = parameter.name?.lexeme ?? '';
      if (parameter.type != null) {
        type = parameter.type!.toSource();
      }
    }
    isOptional = true;
    isNamed = param.isNamed;
    if (param.defaultValue != null) {
      defaultValue = param.defaultValue!.toSource();
    }
  }

  return ParameterInfo(
    name: name,
    type: type,
    isOptional: isOptional,
    isNamed: isNamed,
    defaultValue: defaultValue,
  );
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
