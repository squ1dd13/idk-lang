import 'package:language/runtime/type.dart';

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
  bool _isStatic = false;

  VariableDeclaration(TokenStream tokens) {
    // Find the location of the "=", then work backwards to find the name
    //  and the type.
    // TODO: Work out if there is any way a type could contain a top-level "=".

    // Read the whole statement.
    var statementTokens = tokens.takeUntilSemicolon();

    // Skip the semicolon so the next pass doesn't find it.
    tokens.skip();

    const equalsPattern = TokenPattern(string: '=', type: TokenType.Symbol);

    // Find the "=".
    var equalsIndex = statementTokens
        .lastIndexWhere((token) => equalsPattern.hasMatch(token));

    // If the index is less than 1, it's 0 or -1. -1 means "not found", and 0
    //  just means that it is the first token, which is not what we want.
    if (equalsIndex < 1) {
      statementTokens.first
          .throwSyntax('Invalid "=" position in declaration.', 1);
    }

    var nameToken = statementTokens[equalsIndex - 1];

    if (nameToken.type != TokenType.Name) {
      nameToken.throwSyntax('Expected name in declaration.', 2);
    }

    _name = nameToken.toString();

    // The type tokens are all of the tokens that appear before the name.
    var typeTokens = statementTokens.sublist(0, equalsIndex - 1);

    var typeStream = TokenStream(typeTokens, 0);
    if (!typeStream.hasCurrent()) {
      statementTokens.first.throwSyntax('Expected type in declaration.', 3);
    }

    _typeName = TypeName(typeStream);

    if (typeStream.hasCurrent()) {
      typeStream.current().throwSyntax('Unexpected token.', 4);
    }

    // The value expression is everything after the "=".
    var expressionTokens = statementTokens.sublist(equalsIndex + 1);

    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Declaration value expression may not be empty.', 5);
    }

    _valueExpression = Parse.expression(expressionTokens);
    //
    // _isStatic = Parse.staticKeyword(tokens);
    // _typeName = TypeName(tokens);
    //
    // tokens.requireNext('Expected name after type in declaration.', 2,
    //     TokenPattern.type(TokenType.Name));
    //
    // _name = tokens.take().toString();
    //
    // tokens.requireNext('Expected "=" in declaration.', 3,
    //     TokenPattern(string: '=', type: TokenType.Symbol));
    //
    // // We don't need to keep the '=' token.
    // tokens.skip();
    //
    // var expressionTokens = tokens.takeUntilSemicolon();
    // if (expressionTokens.isEmpty) {
    //   throw tokens.createException(
    //       'Declaration value expression may not be empty.', 4);
    // }
    //
    // _valueExpression = Parse.expression(expressionTokens);
    //
    // // Ensure we have a semicolon at the end.
    // tokens.consumeSemicolon(5);
  }

  @override
  Statement createStatement() {
    return Statement(InlineExpression(() {
      // Evaluate the expression and then create a variable with the type.
      var sourceValue = _valueExpression.evaluate();

      // If _typeName evaluates to 'null', this is a 'let' declaration.
      // We take the type from the value.
      var declaredType = _typeName.evaluate() ?? sourceValue.handleType;

      var variable = sourceValue.convertHandleTo(
          declaredType is ValueType ? declaredType : declaredType.type);

      Store.current().add(_name, variable);

      return null;
    }), static: _isStatic);
  }

  @override
  String toString() {
    return 'type ${_typeName.toString()} set ${_name} as ${_valueExpression}';
  }
}
