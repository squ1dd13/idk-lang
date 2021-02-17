import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/store.dart';
import 'package:language/runtime/type.dart';

import 'parser.dart';
import 'util.dart';

class Loop implements Statable {
  /// For specifying a loop to do something with, such as "break outer".
  String _name;

  Statement _setup;
  Expression _check;
  Expression _change;
  List<Statement> _body;

  Loop(TokenStream tokens) {
    tokens.requireNext('Expected "for" in loop statement.', 1,
        TokenPattern(string: 'for', type: TokenType.Name));

    tokens.skip();

    // We're going to be reading ahead, so save the index so we can come back.
    tokens.saveIndex();

    // To work out if this is a for-each or just a for loop, we compare the
    //  number of tokens there are before the next semicolon to the number of
    //  tokens there are before the next braced group. If a semicolon comes
    //  before the braces, we know that this must be a for loop.
    var untilSemicolon = tokens.takeUntilSemicolon();
    tokens.restoreIndex();

    var untilBraces = tokens.takeWhile(GroupPattern('{', '}').notMatch);

    // We don't restore after finding the braces, because we have all the
    //  tokens we need until then.

    var isForEach = untilBraces.length < untilSemicolon.length;

    if (!isForEach) {
      // Read three statements from the pre-brace tokens. We have to add
      //  a semicolon at the end because the third statement doesn't require
      //  one from the user.
      untilBraces.add(TextToken(TokenType.Symbol, ';'));

      var headerStream = TokenStream(untilBraces, 0);
      _setup = Parse.statement(headerStream);

      var checkTokens = headerStream.takeUntilSemicolon();
      _check = Parse.expression(checkTokens);

      headerStream.consumeSemicolon(2);

      var changeTokens = headerStream.takeUntilSemicolon();
      _change = Parse.expression(changeTokens);
    }

    _body = Parse.statements(tokens.take().allTokens());
  }

  @override
  Statement createStatement() {
    return SideEffectStatement(() {
      var sideEffect = SideEffect();

      Store.current().branch((_) {
        var setupEffect = _setup.execute();

        // Handle interrupts in the setup (probably exceptions).
        if (setupEffect.interrupts) {
          sideEffect = setupEffect;
          return;
        }

        while (true) {
          var checkResult = _check.evaluate();
          var checkInteger =
              checkResult.get().mustConvertTo(PrimitiveType.integer);

          if (checkInteger.equals(IntegerValue.raw(0))) {
            break;
          }

          for (var statement in _body) {
            var statementEffect = statement.execute();

            if (!statementEffect.interrupts) {
              continue;
            }

            if (_name == statementEffect.continueName) {
              // We break to continue, because we're inside the statement
              //  loop as well as the actual loop.
              break;
            }

            if (_name == statementEffect.breakName) {
              // We return from the branch closure to break the loop.
              return;
            }

            // This effect will be handled by something else (another loop
            //  or possibly a function).
            sideEffect = statementEffect;
            return;
          }

          _change.evaluate();
        }

        sideEffect = SideEffect();
      });

      return sideEffect;
    });
  }
}
