import 'handle.dart';

abstract class Expression {
  // TODO: Side effects for expressions (for exceptions).
  Handle? evaluate();
}

class InlineExpression implements Expression {
  final Handle? Function() _action;

  InlineExpression(this._action);

  @override
  Handle? evaluate() {
    return _action();
  }
}
