/// Base class for Result types - immutable and pure
abstract class Result<T, E> {
  const Result();

  /// True if this is a successful result
  bool get isSuccess => this is Success<T, E>;

  /// True if this is a failure result
  bool get isFailure => this is Failure<T, E>;

  /// Map over the success value
  Result<U, E> map<U>(U Function(T) f) {
    if (this is Success<T, E>) {
      return Success(f((this as Success<T, E>).value));
    }
    return Failure((this as Failure<T, E>).error);
  }

  /// FlatMap for chaining Results - key for functional composition
  Result<U, E> flatMap<U>(Result<U, E> Function(T) f) {
    if (this is Success<T, E>) {
      return f((this as Success<T, E>).value);
    }
    return Failure((this as Failure<T, E>).error);
  }

  /// Map over the error type
  Result<T, F> mapError<F>(F Function(E) f) {
    if (this is Success<T, E>) {
      return Success((this as Success<T, E>).value);
    }
    return Failure(f((this as Failure<T, E>).error));
  }

  /// Fold the result into a single value
  U fold<U>(U Function(E) onFailure, U Function(T) onSuccess) {
    if (this is Success<T, E>) {
      return onSuccess((this as Success<T, E>).value);
    }
    return onFailure((this as Failure<T, E>).error);
  }
}

/// Success case - immutable value container
class Success<T, E> extends Result<T, E> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Failure case - immutable error container
class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);

  final E error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}
