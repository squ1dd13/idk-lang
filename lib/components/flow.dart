import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/statements.dart';

import '../parser.dart';
import 'util.dart';

class LoopFlowStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  String keyword;
  String targetName = '';

  @override
  SideEffect execute() {
    if (keyword == 'break') {
      return SideEffect.breaks(name: targetName);
    }

    if (keyword == 'continue') {
      return SideEffect.continues(name: targetName);
    }

    throw Exception('wtf');
  }
}

class ReturnStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  Expression returnExpression;

  @override
  SideEffect execute() {
    return SideEffect.returns(returnExpression.evaluate());
  }
}

class FlowStatement implements Statable {
  // final _statement = LoopFlowStatement();

  DynamicStatement _statement;

  FlowStatement(TokenStream tokens) {
    tokens.requireNext(
        'Flow statement must start with "break", "return" or "continue".',
        1,
        TokenPattern.type(TokenType.Name));

    var keyword = tokens.take().toString();

    if (keyword != 'break' && keyword != 'continue' && keyword != 'return') {
      throw tokens.createException(
          'Flow statement must start with "break", "return" or "continue".', 2);
    }

    if (TokenPattern.semicolon.hasMatch(tokens.current())) {
      // Semicolon, so end here after skipping it.
      tokens.skip();

      var loopStatement = LoopFlowStatement();
      loopStatement.keyword = keyword;
      _statement = loopStatement;

      return;
    }

    if (keyword == 'return') {
      var returnStatement = ReturnStatement();

      // There must be a value if there wasn't a semicolon.
      var untilSemicolon = tokens.takeUntilSemicolon();
      tokens.consumeSemicolon(3);

      returnStatement.returnExpression = Parse.expression(untilSemicolon);

      _statement = returnStatement;
      return;
    }

    var loopStatement = LoopFlowStatement();
    loopStatement.keyword = keyword;

    tokens.requireNext('"${keyword}" may only specify a loop by name.', 3,
        TokenPattern.type(TokenType.Name));

    loopStatement.targetName = tokens.take().toString();
    _statement = loopStatement;

    // There has to be a semicolon now.
    tokens.consumeSemicolon(4);
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}
