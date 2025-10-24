/// Immutable container for annotation information
class AnnotationInfo {
  const AnnotationInfo({
    required this.name,
    this.customName,
    this.debounceExpression,
    this.useRefreshing,
  });

  final String name;
  final String? customName;
  final String? debounceExpression;
  final bool? useRefreshing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          customName == other.customName &&
          debounceExpression == other.debounceExpression &&
          useRefreshing == other.useRefreshing;

  @override
  int get hashCode =>
      Object.hash(name, customName, debounceExpression, useRefreshing);

  @override
  String toString() =>
      'AnnotationInfo(name: $name, customName: $customName, debounceExpression: $debounceExpression, useRefreshing: $useRefreshing)';
}

/// Immutable container for field information
class FieldInfo {
  const FieldInfo({
    required this.name,
    required this.type,
    this.initialValue,
    required this.isNullable,
    required this.isFinal,
    required this.isConst,
    required this.location,
  });

  final String name;
  final String type;
  final String? initialValue;
  final bool isNullable;
  final bool isFinal;
  final bool isConst;
  final String location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          initialValue == other.initialValue &&
          isNullable == other.isNullable &&
          isFinal == other.isFinal &&
          isConst == other.isConst &&
          location == other.location;

  @override
  int get hashCode => Object.hash(
    name,
    type,
    initialValue,
    isNullable,
    isFinal,
    isConst,
    location,
  );

  @override
  String toString() =>
      'FieldInfo('
      'name: $name, '
      'type: $type, '
      'initialValue: $initialValue, '
      'isNullable: $isNullable, '
      'isFinal: $isFinal, '
      'isConst: $isConst, '
      'location: $location'
      ')';
}

/// Immutable container for getter information
class GetterInfo {
  const GetterInfo({
    required this.name,
    required this.returnType,
    required this.expression,
    required this.isNullable,
    required this.location,
  });

  final String name;
  final String returnType;
  final String expression;
  final bool isNullable;
  final String location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetterInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          returnType == other.returnType &&
          expression == other.expression &&
          isNullable == other.isNullable &&
          location == other.location;

  @override
  int get hashCode =>
      Object.hash(name, returnType, expression, isNullable, location);

  @override
  String toString() =>
      'GetterInfo('
      'name: $name, '
      'returnType: $returnType, '
      'expression: $expression, '
      'isNullable: $isNullable, '
      'location: $location'
      ')';
}

/// Immutable container for method information
class MethodInfo {
  const MethodInfo({
    required this.name,
    required this.returnType,
    required this.body,
    required this.parameters,
    required this.isAsync,
    required this.location,
  });

  final String name;
  final String returnType;
  final String body;
  final List<ParameterInfo> parameters;
  final bool isAsync;
  final String location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MethodInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          returnType == other.returnType &&
          body == other.body &&
          _listEquals(parameters, other.parameters) &&
          isAsync == other.isAsync &&
          location == other.location;

  @override
  int get hashCode => Object.hash(
    name,
    returnType,
    body,
    Object.hashAll(parameters),
    isAsync,
    location,
  );

  @override
  String toString() =>
      'MethodInfo('
      'name: $name, '
      'returnType: $returnType, '
      'body: $body, '
      'parameters: $parameters, '
      'isAsync: $isAsync, '
      'location: $location'
      ')';
}

/// Immutable container for parameter information
class ParameterInfo {
  const ParameterInfo({
    required this.name,
    required this.type,
    required this.isOptional,
    required this.isNamed,
    this.defaultValue,
  });

  final String name;
  final String type;
  final bool isOptional;
  final bool isNamed;
  final String? defaultValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParameterInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          isOptional == other.isOptional &&
          isNamed == other.isNamed &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode =>
      Object.hash(name, type, isOptional, isNamed, defaultValue);

  @override
  String toString() =>
      'ParameterInfo('
      'name: $name, '
      'type: $type, '
      'isOptional: $isOptional, '
      'isNamed: $isNamed, '
      'defaultValue: $defaultValue'
      ')';
}

/// Helper function for comparing lists (since List.== doesn't exist)
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
