import 'ast_models.dart';

/// Pure function to generate Signal declaration code.
/// Same input always produces identical output (deterministic).
String generateSignalDeclaration(
  FieldInfo fieldInfo,
  AnnotationInfo annotationInfo,
) {
  final signalName = fieldInfo.name;
  final signalType = fieldInfo.type;
  final initialValue = fieldInfo.initialValue ?? _getDefaultValue(signalType);
  final customName = annotationInfo.customName ?? signalName;

  // Generate the Signal declaration
  return 'final $signalName = Signal<$signalType>($initialValue, name: \'$customName\');';
}

/// Pure function to generate Computed declaration code.
/// Same inputs always produce identical output (deterministic).
String generateComputedDeclaration(
  GetterInfo getterInfo,
  AnnotationInfo annotationInfo,
  List<String> dependencies,
) {
  final computedName = getterInfo.name;
  final computedType = getterInfo.returnType;
  final customName = annotationInfo.customName ?? computedName;

  // Transform the expression to use .value for reactive dependencies
  final transformedExpression = _transformReactiveAccess(
    getterInfo.expression,
    dependencies,
  );

  // Use 'late final' when Computed references other reactive signals/computed values
  final modifier = dependencies.isNotEmpty ? 'late final' : 'final';

  // Generate the Computed declaration
  return '$modifier $computedName = Computed<$computedType>(() => $transformedExpression, name: \'$customName\');';
}

/// Pure function to generate Effect declaration code.
/// Same inputs always produce identical output (deterministic).
String generateEffectDeclaration(
  MethodInfo methodInfo,
  String transformedBody,
) {
  final effectName = methodInfo.name;

  // Generate the Effect declaration using late final to avoid initializer issues
  return 'late final $effectName = Effect(() $transformedBody, name: \'$effectName\');';
}

/// Pure function to generate Environment declaration code.
/// Same inputs always produce identical output (deterministic).
String generateEnvironmentDeclaration(
  FieldInfo fieldInfo,
  AnnotationInfo annotationInfo,
) {
  final fieldName = fieldInfo.name;
  final fieldType = fieldInfo.type;

  // Generate the context.read<T>() declaration
  return 'late final $fieldName = context.read<$fieldType>();';
}

/// Pure function to generate Resource declaration code.
/// Same inputs always produce identical output (deterministic).
String generateResourceDeclaration(
  MethodInfo methodInfo,
  AnnotationInfo annotationInfo,
  List<String> dependencies,
) {
  final resourceName = methodInfo.name;
  final customName = annotationInfo.customName ?? resourceName;

  // Extract the return type from Future<T> or Stream<T> -> T
  final returnType = _extractGenericType(methodInfo.returnType);

  // Check if this is a Stream method
  final isStream = methodInfo.returnType.startsWith('Stream<');

  // Transform the method body to use .value for reactive dependencies
  final transformedBody = _transformReactiveAccess(
    methodInfo.body,
    dependencies,
  );

  // Generate the Resource declaration
  final buffer = StringBuffer();

  if (isStream) {
    // For streams, use Resource<T>.stream() constructor
    buffer.write('late final $resourceName = Resource<$returnType>.stream(');
  } else {
    // For futures, use regular Resource<T>() constructor
    buffer.write('late final $resourceName = Resource<$returnType>(');
  }

  // If it's an async method, wrap in async function
  if (methodInfo.isAsync) {
    buffer.write('() async $transformedBody');
  } else {
    buffer.write('() $transformedBody');
  }

  // Add source parameter if there are reactive dependencies
  if (dependencies.isNotEmpty) {
    if (dependencies.length == 1) {
      buffer.write(', source: ${dependencies.first}');
    } else {
      // Multiple dependencies - create a Computed that combines all dependencies
      final sourceName = '${resourceName}Source';
      final dependencyValues = dependencies
          .map((dep) => '$dep.value')
          .join(', ');
      buffer.write(
        ', source: Computed(() => ($dependencyValues), name: \'$sourceName\')',
      );
    }
  }

  // Add name parameter
  buffer.write(', name: \'$customName\'');

  // Add debounce parameter if specified
  if (annotationInfo.debounceExpression != null) {
    buffer.write(', debounceDelay: const ${annotationInfo.debounceExpression}');
  }

  // Add useRefreshing parameter if specified
  if (annotationInfo.useRefreshing != null) {
    buffer.write(', useRefreshing: ${annotationInfo.useRefreshing}');
  }

  buffer.write(');');

  return buffer.toString();
}

/// Pure function to generate SignalBuilder widget wrapper.
/// Same inputs always produce identical output (deterministic).
String generateSignalBuilderWrapper(
  String originalWidget,
  List<String> dependencies,
) {
  if (dependencies.isEmpty) {
    return originalWidget;
  }

  return 'SignalBuilder(\n'
      '  builder: (context, child) {\n'
      '    return $originalWidget;\n'
      '  }\n'
      ')';
}

/// Pure function to generate disposal code for reactive primitives.
/// Same inputs always produce identical output (deterministic).
String generateDisposalCode(List<String> reactiveNames) {
  if (reactiveNames.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  buffer.writeln('@override');
  buffer.writeln('void dispose() {');

  // Dispose in proper order: Effects, Resources, Computed, Signals
  for (final name in reactiveNames) {
    buffer.writeln('  $name.dispose();');
  }

  buffer.writeln('  super.dispose();');
  buffer.writeln('}');

  return buffer.toString();
}

/// Pure helper function to get default value for a type
String _getDefaultValue(String type) {
  // Check for nullable first
  if (type.endsWith('?')) {
    return 'null';
  }

  final cleanType = type.replaceAll('?', ''); // Remove nullable marker

  switch (cleanType) {
    case 'int':
      return '0';
    case 'double':
      return '0.0';
    case 'bool':
      return 'false';
    case 'String':
      return "''";
    default:
      // For complex types, try to provide a reasonable default
      if (cleanType.startsWith('List')) {
        return '[]';
      }
      if (cleanType.startsWith('Map')) {
        return '{}';
      }
      if (cleanType.startsWith('Set')) {
        return '{}';
      }
      // For custom types, use null as default
      return 'null';
  }
}

/// Pure helper function to transform reactive variable access
/// Converts variable references to variable.value for reactive dependencies
String _transformReactiveAccess(String code, List<String> dependencies) {
  String transformedCode = code;

  // Transform reactive variable access to use .value
  for (final dependency in dependencies) {
    // Handle string interpolation first - transform $dependency to ${dependency.value}
    final interpolationPattern = RegExp(
      r'\$' + dependency + r'(?!\.value)(?!\w)',
    );
    transformedCode = transformedCode.replaceAll(
      interpolationPattern,
      '\${$dependency.value}',
    );

    // Handle other variable access patterns (not in string interpolation)
    final variablePattern = RegExp(
      r'(?<!\$)\b' + dependency + r'\b(?!\.value)',
    );
    transformedCode = transformedCode.replaceAll(
      variablePattern,
      '$dependency.value',
    );
  }

  return transformedCode;
}

/// Pure helper function to extract generic type from Future\<T> or Stream\<T>
String _extractGenericType(String type) {
  if (type.startsWith('Future<') && type.endsWith('>')) {
    return type.substring(7, type.length - 1);
  }
  if (type.startsWith('Stream<') && type.endsWith('>')) {
    return type.substring(7, type.length - 1);
  }
  return type;
}
