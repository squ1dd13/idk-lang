import '../Lexer.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';

class Parser {
  List<Token> _tokens;

  static Expression parseTokens(List<Token> tokens) {
    if (tokens.length == 1) {
      if (tokens.first.type == TokenType.String) {
        return InlineExpression(() => StringValue(tokens.first.toString()));
      }

      if (tokens.first.type == TokenType.Number) {
        return InlineExpression(() => IntegerValue(tokens.first.toString()));
      }
    }

    return InlineExpression(() {
      print('Unparsed!');
      return null;
    });
  }

  Parser(this._tokens) {}
}
