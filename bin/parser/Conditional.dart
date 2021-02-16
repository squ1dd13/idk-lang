import '../Lexer.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';
import '../runtime/Types.dart';
import 'Parser.dart';
import 'Util.dart';

/// Any part of an if..else if..else statement.
class ConditionalClause implements Statable {
  /// [null] if there is no condition (for 'else').
  Expression _condition;
  List<Statement> _body;
  ConditionalClause _nextClause;

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

      _condition = Parse.expression(conditionTokens);
    }

    if (bodyPattern.notMatch(tokens.current())) {
      throw tokens.createException(
          'Expected braces after start of "$clauseKeyword".', 3);
    }

    // Parse the body into a list of statements.
    _body = Parse.statements(tokens.take().allTokens());

    // Check if there's a chained clause after this.
    if (TokenPattern(string: 'else', type: TokenType.Name)
        .hasMatch(tokens.current())) {
      _nextClause = ConditionalClause(tokens);
    }
  }

  @override
  Statement createStatement() {
    return SideEffectStatement(() {
      var conditionValue = true;

      if (_condition != null) {
        // TODO: Introduce Boolean type.
        var convertedToInt = _condition.evaluate()
            .get()
            .mustConvertTo(PrimitiveType(Primitive.Int));

        conditionValue = (convertedToInt as IntegerValue).value != 0;
      }

      if (!conditionValue) {
        // Run the subsequent clause, or return if it is null.
        return _nextClause?.createStatement()?.execute() ?? SideEffects();
      }

      for (var bodyStatement in _body) {
        var statementEffect = bodyStatement.execute();

        if (statementEffect.interrupts) {
          return statementEffect;
        }
      }

      return SideEffects();
    });
  }
}
