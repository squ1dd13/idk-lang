import 'package:language/runtime/expression.dart';

import '../lexer.dart';
import 'operations/expression.dart';
import 'util.dart';

class TypeName {
  Expression? _typeExpression;

  TypeName(TokenStream tokens) {
    const letPattern = TokenPattern(string: 'let', type: TokenType.Name);

    if (letPattern.hasMatch(tokens.current())) {
      // 'let' means the value gives the type.
      _typeExpression = null;
      tokens.skip();
      return;
    }

    _typeExpression = OperatorExpression(tokens);
  }

  dynamic evaluate() {
    return _typeExpression?.evaluate()?.value;
  }
}
