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
  Expression expression;

  @override
  SideEffect execute() {
    return SideEffect.returns(expression.evaluate());
  }
}

class ThrowStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  Expression expression;

  @override
  SideEffect execute() {
    return SideEffect.throws(expression.evaluate());
  }
}

class FlowStatement implements Statable {
  DynamicStatement _statement;

  FlowStatement(TokenStream tokens) {
    tokens.requireNext(
        'Flow statement must start with "break", "return", "throw" or "continue".',
        1,
        TokenPattern.type(TokenType.Name));

    var keyword = tokens.take().toString();

    const keywords = <String>{
      'break',
      'continue',
      'throw',
      'return',
    };

    if (!keywords.contains(keyword)) {
      throw tokens.createException(
          'Flow statement must start with "break", "return", "throw" or "continue".',
          2);
    }

    if (TokenPattern.semicolon.hasMatch(tokens.current())) {
      // Semicolon, so end here after skipping it.
      tokens.skip();

      var loopStatement = LoopFlowStatement();
      loopStatement.keyword = keyword;
      _statement = loopStatement;

      return;
    }

    if (keyword == 'return' || keyword == 'throw') {
      dynamic statement =
          keyword == 'return' ? ReturnStatement() : ThrowStatement();

      // There must be a value if there wasn't a semicolon.
      var untilSemicolon = tokens.takeUntilSemicolon();
      tokens.consumeSemicolon(3);

      statement.expression = Parse.expression(untilSemicolon);

      _statement = statement;
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
