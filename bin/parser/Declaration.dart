import '../Lexer.dart';
import '../runtime/Concepts.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';
import '../runtime/Store.dart';
import 'Parser.dart';
import 'TypeName.dart';
import 'Util.dart';

class VariableDeclaration {
  TypeName _typeName;
  String _name;
  Expression _valueExpression;

  VariableDeclaration(TokenStream tokens) {
    tokens.requireNext('Declaration must begin with a type name.', 1,
        TokenPattern.type(TokenType.Name));

    _typeName = TypeName(tokens);

    tokens.requireNext('Expected name after type in declaration.', 2,
        TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();

    tokens.requireNext('Expected "=" in declaration.', 3,
        TokenPattern(string: '=', type: TokenType.Symbol));

    // We don't need to keep the '=' token.
    tokens.skip();

    var expressionTokens = tokens.takeWhile(TokenPattern.semicolon.notMatch);
    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Declaration value expression may not be empty.', 4);
    }

    _valueExpression = Parse.expression(expressionTokens);

    // Ensure we have a semicolon at the end.
    tokens.consumeSemicolon(5);
  }

  Statement createStatement() {
    return Statement(InlineExpression(() {
      // Evaluate the expression and then create a variable with the type.
      var evaluated = _valueExpression.evaluate();

      // TODO: Check that the evaluated result and type actually match.
      var variable = Variable(_typeName.evaluate(), evaluated);

      Store.current().add(_name, variable);
      return null;
    }));
  }

  @override
  String toString() {
    return 'type ${_typeName.toString()} set ${_name} as ${_valueExpression}';
  }
}
