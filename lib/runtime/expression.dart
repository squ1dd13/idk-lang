import 'abstract.dart';

abstract class Expression {
  Evaluable evaluate();
}

class InlineExpression implements Expression {
  final Evaluable Function() _action;

  InlineExpression(this._action);

  @override
  Evaluable evaluate() {
    return _action();
  }
}
