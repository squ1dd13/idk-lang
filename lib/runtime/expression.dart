import 'abstract.dart';

abstract class Expression {
  // TODO: Side effects for expressions (for exceptions).
  Value evaluate();
}

class InlineExpression implements Expression {
  final Evaluable Function() _action;

  InlineExpression(this._action);

  @override
  Value evaluate() {
    return _action();
  }
}
