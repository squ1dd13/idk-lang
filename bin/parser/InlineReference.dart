import '../Lexer.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';
import 'Parser.dart';
import 'Util.dart';

/// Inline direction of references.
/// ```
/// someFunction(-> target);
/// ```
class InlineReference implements Expressible {
  Expression _targetExpression;

  InlineReference(TokenStream tokens) {
    tokens.requireNext('Token direction must begin with "->".', 1,
        TokenPattern(string: '->', type: TokenType.Symbol));

    tokens.skip();

    // The next must be a single token, so multiple tokens must be
    //  parenthesised.
    var expressionTokens = tokens.take().allTokens();
    _targetExpression = Parse.expression(expressionTokens);
  }

  @override
  Expression createExpression() {
    return InlineExpression(() => Reference(_targetExpression.evaluate()));
  }
}
