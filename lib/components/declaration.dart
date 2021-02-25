import 'package:language/runtime/statements.dart';
import 'package:language/runtime/type.dart';

import '../lexer.dart';
import '../parser.dart';
import '../runtime/concrete.dart';
import '../runtime/expression.dart';
import '../runtime/store.dart';
import 'typename.dart';
import 'util.dart';

class DeclarationStatement extends Statement
    implements ClassChild, FunctionChild, LoopChild {
  TypeName typeName;
  String name;
  Expression valueExpression;

  DeclarationStatement(bool isStatic) : super(isStatic);

  @override
  SideEffect execute() {
    // Evaluate the expression and then create a variable with the type.
    var sourceValue = valueExpression.evaluate();

    // If typeName evaluates to 'null', this is a 'let' declaration.
    // We take the type from the value.
    var declaredType = typeName.evaluate() ?? sourceValue.handleType;

    var endType = declaredType is ValueType ? declaredType : declaredType.type;
    var variable = sourceValue.convertHandleTo(endType);

    Store.current().add(name, variable);

    return SideEffect.nothing();
  }
}

class VariableDeclaration implements Statable {
  // TODO: Add back statics declarations.
  final _statement = DeclarationStatement(false);

  VariableDeclaration(TokenStream tokens) {
    // Find the location of the "=", then work backwards to find the name
    //  and the type.
    // TODO: Work out if there is any way a type could contain a top-level "=".

    // TODO: Dart-style valueless declarations with null value.

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

    _statement.name = nameToken.toString();

    // The type tokens are all of the tokens that appear before the name.
    var typeTokens = statementTokens.sublist(0, equalsIndex - 1);

    var typeStream = TokenStream(typeTokens, 0);
    if (!typeStream.hasCurrent()) {
      statementTokens.first.throwSyntax('Expected type in declaration.', 3);
    }

    _statement.typeName = TypeName(typeStream);

    if (typeStream.hasCurrent()) {
      typeStream.current().throwSyntax('Unexpected token.', 4);
    }

    // The value expression is everything after the "=".
    var expressionTokens = statementTokens.sublist(equalsIndex + 1);

    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Declaration value expression may not be empty.', 5);
    }

    _statement.valueExpression = Parse.expression(expressionTokens);
  }

  @override
  Statement createStatement() {
    return _statement;
  }

  @override
  String toString() {
    return 'type ${_statement.typeName.toString()} '
        'set ${_statement.name} '
        'as ${_statement.valueExpression}';
  }
}
