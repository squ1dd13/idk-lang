import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/scope.dart';
import 'package:language/runtime/statements.dart';

import 'util.dart';

class FinallyStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  final DynamicStatement _statement;

  FinallyStatement(this._statement);

  @override
  SideEffect execute() {
    Scope.current().defer(() {
      // Return the side effect even though we don't need to return anything at
      //  all. This causes a runtime exception to be thrown when something is
      //  thrown from inside a deferred statement.
      return _statement.execute();
    });

    return SideEffect.nothing();
  }
}

class Finally implements Statable {
  FinallyStatement _statement;

  Finally(TokenStream tokens) {
    tokens.requireNext('Expected "finally".', 1,
        TokenPattern(string: 'finally', type: TokenType.Name));

    tokens.skip();

    _statement = FinallyStatement(Parse.statement(tokens));
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}
