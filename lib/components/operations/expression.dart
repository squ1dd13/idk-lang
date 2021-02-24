import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/handle.dart';

import 'parser.dart';

class OperatorExpression implements Expression {
  List<Token> _tokens;

  OperatorExpression(TokenStream tokens) {
    // Infix expressions can't have two operands next to each other,
    //  so the expression ends when we find a semicolon or two tokens
    //  that would be operands.

    var lastWasOperand = false;
    var found = <Token>[];

    while (tokens.hasCurrent() &&
        TokenPattern.semicolon.notMatch(tokens.current())) {
      var notOperator = tokens.current().isNotOperator &&
          GroupPattern('(', ')').notMatch(tokens.current());

      if (notOperator && lastWasOperand) {
        break;
      }

      found.add(tokens.take());
      lastWasOperand = notOperator;
    }

    if (found.length == 1 && found[0].type == TokenType.Symbol) {
      found.first.throwSyntax('Invalid expression! Found only one symbol.', 1);
    }

    _tokens = found;
    _preprocess();
  }

  void _preprocess() {
    _findHiddenUnaryOperators();
    _stringifyMemberAccess('.');
    _stringifyMemberAccess(':');
    _tokens = ShuntingYard.toPostfix(_tokens);
  }

  void _findHiddenUnaryOperators() {
    const minusPattern = TokenPattern(string: '-', type: TokenType.Symbol);

    for (var i = 0; i < _tokens.length; ++i) {
      if (minusPattern.hasMatch(_tokens[i])) {
        var isUnary = false;

        if (i == 0) {
          isUnary = true;
        } else {
          var previousOperator = ShuntingYard.getOperator(_tokens[i - 1]);

          if (previousOperator != null && previousOperator.fixity == Fix.In) {
            isUnary = true;
          }
        }

        if (isUnary) {
          _tokens[i] = TextToken(TokenType.Symbol, '-u');
        }
      }
    }
  }

  void _stringifyMemberAccess(String accessOperator) {
    var nextIsMember = false;
    var output = <Token>[];

    var pattern = TokenPattern(string: accessOperator, type: TokenType.Symbol);

    for (var token in _tokens) {
      if (nextIsMember) {
        if (token.type != TokenType.Name) {
          // token.throwSyntax(
          //     '"$accessOperator" operator must precede '
          //     'a valid name.',
          //     10);
        }

        token.type = TokenType.String;
        nextIsMember = false;
      } else {
        nextIsMember = pattern.hasMatch(token);
      }

      output.add(token);
    }

    _tokens = output;
  }

  @override
  Handle evaluate() {
    return ShuntingYard.evaluate(_tokens);
  }
}
