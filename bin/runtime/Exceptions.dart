class RuntimeError implements Exception {
  final String message;

  RuntimeError(this.message);

  @override
  String toString() => 'Runtime error: $message';
}
