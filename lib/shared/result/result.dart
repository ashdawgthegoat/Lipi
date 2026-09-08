import '../errors/lipi_error.dart';

/// Represents the outcome of an operation that can either succeed with [T]
/// or fail with a domain/infrastructure error [E].
///
/// Follows ADR-0008 and IMPLEMENTATION-CONTRACT Section 28 & 29.
sealed class Result<T, E extends LipiError> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  E? get errorOrNull => switch (this) {
        Success() => null,
        Failure(:final error) => error,
      };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final error) => onFailure(error),
      };

  Result<U, E> map<U>(U Function(T value) transform) => switch (this) {
        Success(:final value) => Success(transform(value)),
        Failure(:final error) => Failure(error),
      };

  Result<T, F> mapError<F extends LipiError>(F Function(E error) transform) =>
      switch (this) {
        Success(:final value) => Success(value),
        Failure(:final error) => Failure(transform(error)),
      };
}

final class Success<T, E extends LipiError> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T, E> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

final class Failure<T, E extends LipiError> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Failure<T, E> && other.error == error);

  @override
  int get hashCode => error.hashCode;
}
