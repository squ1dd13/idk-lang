class RuntimeError implements Exception {
  final String message;

  RuntimeError(this.message);

  @override
  String toString() => 'Runtime error: $message';
}

class InternalException extends RuntimeError {
  InternalException(String message) : super(message);

  @override
  String toString() => 'Internal exception: $message';
}
