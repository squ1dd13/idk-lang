import '../Lexer.dart';
import '../runtime/Expression.dart';
import '../runtime/Store.dart';
import 'Parser.dart';
import 'Util.dart';

class VariableDeclaration {
  Token _typeToken;
  Token _nameToken;
  var _expressionTokens = <Token>[];

  VariableDeclaration(TokenStream tokens) {
    tokens.requireNext('Declaration must begin with a type name.', 1,
        TokenPattern.type(TokenType.Name));

    _typeToken = tokens.take();

    tokens.requireNext('Expected name after type in declaration.', 2,
        TokenPattern.type(TokenType.Name));

    _nameToken = tokens.take();

    tokens.requireNext('Expected "=" in declaration.', 3,
        TokenPattern(string: '=', type: TokenType.Symbol));

    // We don't need to keep the '=' token.
    tokens.skip();

    _expressionTokens = tokens.takeWhile(TokenPattern.semicolon.notMatch);
    if (_expressionTokens.isEmpty) {
      throw tokens.createException(
          'Declaration value expression may not be empty.', 4);
    }

    // Ensure we have a semicolon at the end.
    tokens.consumeSemicolon(5);
  }

  Expression createExpression() {
    return InlineExpression(() {
      var parsedValue = Parser.parseTokens(_expressionTokens).evaluate();
      Store.current().add(_nameToken.toString(), parsedValue);
      return null;
    });
  }

  @override
  String toString() {
    return 'type $_typeToken set $_nameToken as $_expressionTokens';
  }
}
