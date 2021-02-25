import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/primitive.dart';
import 'package:language/runtime/statements.dart';
import 'package:language/runtime/store.dart';

class ConditionalStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  /// null if there is no condition (for 'else').
  Expression condition;
  List<Statement> body;
  ConditionalClause nextClause;

  @override
  SideEffect execute() {
    var sideEffect = SideEffect.nothing();

    Store.current().branch((_) {
      var conditionValue = true;

      if (condition != null) {
        var evaluated = condition.evaluate();
        var conditionBool = evaluated.convertValueTo(PrimitiveType.boolean);

        conditionValue = (conditionBool.value as BooleanValue).value;
      }

      if (!conditionValue) {
        // Run the subsequent clause, or return an empty side effect if there
        //  isn't another clause to run.
        sideEffect =
            nextClause?.createStatement()?.execute() ?? SideEffect.nothing();
        return;
      }

      for (var bodyStatement in body) {
        var statementEffect = bodyStatement.execute();

        if (statementEffect.isInterrupt) {
          sideEffect = statementEffect;
          return;
        }
      }
    });

    return sideEffect;
  }
}

/// Any part of an if..else if..else statement.
class ConditionalClause implements Statable {
  /// null if there is no condition (for 'else').
  // Expression _condition;
  // List<Statement> _body;
  // ConditionalClause _nextClause;

  final _statement = ConditionalStatement();

  ConditionalClause(TokenStream tokens) {
    tokens.requireNext(
        'Conditional keyword expected.', 1, TokenPattern.type(TokenType.Name));

    var shouldReadCondition = false;
    var clauseKeyword = tokens.take().toString();

    if (clauseKeyword == 'else') {
      shouldReadCondition = TokenPattern(string: 'if', type: TokenType.Name)
          .hasMatch(tokens.current());

      if (shouldReadCondition) {
        clauseKeyword = 'else if';

        // Skip the 'if' in the 'else if'.
        tokens.skip();
      }
    } else if (clauseKeyword == 'if') {
      shouldReadCondition = true;
    } else {
      throw tokens.createException(
          'Expected "if", "else if" or "else" in conditional, '
          'got "$clauseKeyword" instead.',
          2);
    }

    var bodyPattern = GroupPattern('{', '}');

    if (shouldReadCondition) {
      var conditionTokens = tokens.takeWhile(bodyPattern.notMatch);

      _statement.condition = Parse.expression(conditionTokens);
    }

    if (bodyPattern.notMatch(tokens.current())) {
      throw tokens.createException(
          'Expected braces after start of "$clauseKeyword".', 3);
    }

    // Parse the body into a list of statements.
    _statement.body =
        Parse.statements<DynamicStatement>(tokens.take().allTokens());

    // Check if there's a chained clause after this.
    if (tokens.hasCurrent() &&
        TokenPattern(string: 'else', type: TokenType.Name)
            .hasMatch(tokens.current())) {
      _statement.nextClause = ConditionalClause(tokens);
    }
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}
