import '../errors/app_exception.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException exception) onFailure,
  }) {
    final value = this;
    if (value is Success<T>) {
      return onSuccess(value.data);
    }
    return onFailure((value as Failure<T>).exception);
  }
}

class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

class Failure<T> extends Result<T> {
  const Failure(this.exception);

  final AppException exception;
}
