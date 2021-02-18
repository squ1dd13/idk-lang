import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';

import 'parser.dart';
import 'util.dart';

class FlowStatement implements Statable {
  String _keyword;
  String _targetName = '';
  Expression _returnExpression;

  FlowStatement(TokenStream tokens) {
    tokens.requireNext(
        'Flow statement must start with "break", "return" or "continue".',
        1,
        TokenPattern.type(TokenType.Name));

    _keyword = tokens.take().toString();

    if (_keyword != 'break' && _keyword != 'continue' && _keyword != 'return') {
      throw tokens.createException(
          'Flow statement must start with "break", "return" or "continue".', 2);
    }

    if (TokenPattern.semicolon.hasMatch(tokens.current())) {
      // Semicolon, so end here after skipping it.
      tokens.skip();
      return;
    }

    if (_keyword == 'return') {
      // There must be a value if there wasn't a semicolon.
      var untilSemicolon = tokens.takeUntilSemicolon();
      tokens.consumeSemicolon(3);

      _returnExpression = Parse.expression(untilSemicolon);
      return;
    }

    tokens.requireNext('"$_keyword" may only specify a loop by name.', 3,
        TokenPattern.type(TokenType.Name));

    _targetName = tokens.take().toString();

    // There has to be a semicolon now.
    tokens.consumeSemicolon(4);
  }

  @override
  Statement createStatement() {
    return SideEffectStatement(() {
      if (_keyword == 'break') {
        return SideEffect.breaks(name: _targetName);
      }

      if (_keyword == 'continue') {
        return SideEffect.continues(name: _targetName);
      }

      if (_keyword == 'return') {
        return SideEffect.returns(_returnExpression.evaluate());
      }

      throw Exception('wtf');
    });
  }
}
