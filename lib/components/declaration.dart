import '../lexer.dart';
import '../parser.dart';
import '../runtime/concrete.dart';
import '../runtime/expression.dart';
import '../runtime/store.dart';
import 'typename.dart';
import 'util.dart';

class VariableDeclaration implements Statable {
  TypeName _typeName;
  String _name;
  Expression _valueExpression;
  bool _isStatic;

  VariableDeclaration(TokenStream tokens) {
    _isStatic = Parse.staticKeyword(tokens);
    _typeName = TypeName(tokens);

    tokens.requireNext('Expected name after type in declaration.', 2,
        TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();

    tokens.requireNext('Expected "=" in declaration.', 3,
        TokenPattern(string: '=', type: TokenType.Symbol));

    // We don't need to keep the '=' token.
    tokens.skip();

    var expressionTokens = tokens.takeUntilSemicolon();
    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Declaration value expression may not be empty.', 4);
    }

    _valueExpression = Parse.expression(expressionTokens);

    // Ensure we have a semicolon at the end.
    tokens.consumeSemicolon(5);
  }

  @override
  Statement createStatement() {
    return Statement(InlineExpression(() {
      // Evaluate the expression and then create a variable with the type.
      var sourceValue = _valueExpression.evaluate();

      // If _typeName evaluates to 'null', this is a 'let' declaration.
      // We take the type from the value.
      var declaredType = _typeName.evaluate() ?? sourceValue.handleType;

      var variable = sourceValue.convertHandleTo(declaredType);

      Store.current().add(_name, variable);

      return null;
    }), static: _isStatic);
  }

  @override
  String toString() {
    return 'type ${_typeName.toString()} set ${_name} as ${_valueExpression}';
  }
}
