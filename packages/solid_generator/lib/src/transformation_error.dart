/// Base class for all transformation errors - immutable
abstract class TransformationError {
  const TransformationError(this.message, this.location);

  final String message;
  final String? location;

  @override
  String toString() => location != null
      ? 'TransformationError at $location: $message'
      : 'TransformationError: $message';
}

/// Error during annotation parsing - immutable
class AnnotationParseError extends TransformationError {
  const AnnotationParseError(
    super.message,
    super.location,
    this.annotationName,
  );

  final String annotationName;

  @override
  String toString() => location != null
      ? 'AnnotationParseError at $location: Failed to parse @$annotationName - $message'
      : 'AnnotationParseError: Failed to parse @$annotationName - $message';
}

/// Error during field/method analysis - immutable
class AnalysisError extends TransformationError {
  const AnalysisError(super.message, super.location, this.elementName);

  final String elementName;

  @override
  String toString() => location != null
      ? 'AnalysisError at $location: Failed to analyze $elementName - $message'
      : 'AnalysisError: Failed to analyze $elementName - $message';
}

/// Error during code generation - immutable
class CodeGenerationError extends TransformationError {
  const CodeGenerationError(super.message, super.location, this.targetType);

  final String targetType;

  @override
  String toString() => location != null
      ? 'CodeGenerationError at $location: Failed to generate $targetType - $message'
      : 'CodeGenerationError: Failed to generate $targetType - $message';
}

/// Validation error for reactive annotations - immutable
class ValidationError extends TransformationError {
  const ValidationError(super.message, super.location, this.violationType);

  final String violationType;

  /// Factory constructors for common validation errors
  const ValidationError.invalidAnnotationTarget(
    String elementName,
    String location,
  ) : violationType = 'INVALID_TARGET',
      super('@SolidState can only be applied to fields and getters', location);

  const ValidationError.missingAnnotation(String elementName, String? location)
    : violationType = 'MISSING_ANNOTATION',
      super('Expected reactive annotation not found on $elementName', location);

  const ValidationError.invalidType(String typeName, String? location)
    : violationType = 'INVALID_TYPE',
      super('Type $typeName is not supported for reactive state', location);

  @override
  String toString() => location != null
      ? 'ValidationError at $location: [$violationType] $message'
      : 'ValidationError: [$violationType] $message';
}
