import 'package:language/parser/parser.dart';
import 'package:language/parser/util.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';

import '../lexer.dart';

class Assignment implements Statable {
  Expression _destination;
  Expression _source;

  Assignment(TokenStream tokens) {
    var firstPart = tokens
        .takeWhile(TokenPattern(string: '=', type: TokenType.Symbol).notMatch);

    if (firstPart.isEmpty) {
      throw tokens.createException('Cannot assign to empty expression!', 1);
    }

    _destination = Parse.expression(firstPart);

    // Skip '='.
    tokens.skip();

    _source =
        Parse.expression(tokens.takeWhile(TokenPattern.semicolon.notMatch));

    // We don't allow assignments to be expressions (like 'x = (y = z)'), so
    //  there must be a semicolon at the end.
    tokens.consumeSemicolon(3,
        message: 'Expected semicolon after assignment – '
            'assignments may not be expressions.');
  }

  @override
  Statement createStatement() {
    return Statement(InlineExpression(() {
      var target = _destination.evaluate();

      if (!(target is Variable)) {
        throw Exception('Cannot assign to non-variables.');
      }

      var newValue = _source.evaluate().get().copy();

      (target as Variable).set(newValue);

      return null;
    }));
  }
}
