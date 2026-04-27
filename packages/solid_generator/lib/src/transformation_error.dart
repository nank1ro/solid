/// Base class for all transformation errors - immutable.
///
/// Implements [Exception] so subclasses can be `throw`n from the pipeline
/// without tripping the `only_throw_errors` lint.
abstract class TransformationError implements Exception {
  /// Creates a [TransformationError] with [message] and optional [location].
  const TransformationError(this.message, this.location);

  /// Human-readable description of the error.
  final String message;

  /// Source location where the error occurred, or null if unknown.
  final String? location;

  @override
  String toString() => location != null
      ? 'TransformationError at $location: $message'
      : 'TransformationError: $message';
}

/// Error during annotation parsing - immutable
class AnnotationParseError extends TransformationError {
  /// Creates an [AnnotationParseError] for the given [annotationName].
  const AnnotationParseError(
    super.message,
    super.location,
    this.annotationName,
  );

  /// The name of the annotation that failed to parse.
  final String annotationName;

  @override
  String toString() => location != null
      ? 'AnnotationParseError at $location: '
            'Failed to parse @$annotationName - $message'
      : 'AnnotationParseError: Failed to parse @$annotationName - $message';
}

/// Error during field/method analysis - immutable
class AnalysisError extends TransformationError {
  /// Creates an [AnalysisError] for the given [elementName].
  const AnalysisError(super.message, super.location, this.elementName);

  /// The name of the element that failed to analyze.
  final String elementName;

  @override
  String toString() => location != null
      ? 'AnalysisError at $location: Failed to analyze $elementName - $message'
      : 'AnalysisError: Failed to analyze $elementName - $message';
}

/// Error during code generation - immutable
class CodeGenerationError extends TransformationError {
  /// Creates a [CodeGenerationError] for the given [targetType].
  const CodeGenerationError(super.message, super.location, this.targetType);

  /// The name of the type that failed to generate.
  final String targetType;

  @override
  String toString() => location != null
      ? 'CodeGenerationError at $location: '
            'Failed to generate $targetType - $message'
      : 'CodeGenerationError: Failed to generate $targetType - $message';
}

/// Validation error for reactive annotations - immutable
class ValidationError extends TransformationError {
  /// Creates a [ValidationError] with a [violationType] code.
  const ValidationError(super.message, super.location, this.violationType);

  /// Code identifying the type of validation violation.
  final String violationType;

  @override
  String toString() => location != null
      ? 'ValidationError at $location: [$violationType] $message'
      : 'ValidationError: [$violationType] $message';
}
