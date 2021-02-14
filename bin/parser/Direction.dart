import '../Lexer.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';
import '../runtime/Store.dart';
import 'Declaration.dart';
import 'Parser.dart';
import 'TypeName.dart';
import 'Util.dart';

/// The initial direction of a reference, such as:
/// ```
/// @int myReference -> someVariable;
/// ```
class FirstDirection {
  TypeName _typeName;
  String _name;
  Expression _targetExpression;

  FirstDirection(TokenStream tokens) {
    _typeName = TypeName(tokens);

    tokens.requireNext('Expected name after type in direction.', 1,
        TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();

    tokens.requireNext('Expected "->" in direction.', 2,
        TokenPattern(string: '->', type: TokenType.Symbol));

    tokens.skip();

    var expressionTokens = tokens.takeWhile(TokenPattern.semicolon.notMatch);
    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Direction target expression may not be empty.', 3);
    }

    _targetExpression = Parse.expression(expressionTokens);

    tokens.consumeSemicolon(4);
  }

  Statement createStatement() {
    return Statement(InlineExpression(() {
      // Evaluate the expression and then create a variable with the type.
      var evaluated = _targetExpression.evaluate();

      var reference = Reference(evaluated);
      Store.current().add(_name, reference);
      return null;
    }));
  }
}