import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/primitive.dart';
import 'package:language/runtime/scope.dart';
import 'package:language/runtime/statements.dart';

import '../parser.dart';
import 'util.dart';

class LoopStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  /// For specifying a loop to do something with, such as "break outer".
  String name;

  Statement setup;
  Expression check;
  Expression change;
  List<Statement> body;

  @override
  SideEffect execute() {
    var sideEffect = SideEffect.nothing();

    Scope.current().branch((_) {
      var setupEffect = setup.execute();

      // Handle interrupts in the setup (probably exceptions).
      if (setupEffect.isInterrupt) {
        sideEffect = setupEffect;
        return;
      }

      while (true) {
        var checkResult = check.evaluate();

        if (checkResult.value.equals(BooleanValue(false))) {
          break;
        }

        for (var statement in body) {
          var statementEffect = statement.execute();

          if (!statementEffect.isInterrupt) {
            continue;
          }

          if (statementEffect.breaksLoopName(name)) {
            // We return from the branch closure to break the loop.
            return;
          }

          if (statementEffect.continuesLoopName(name)) {
            // We break to continue, because we're inside the statement
            //  loop as well as the actual loop.
            break;
          }

          // This effect will be handled by something else (another loop
          //  or possibly a function).
          sideEffect = statementEffect;
          return;
        }

        change.evaluate();
      }

      sideEffect = SideEffect.nothing();
    });

    return sideEffect;
  }
}

class Loop implements Statable {
  final _statement = LoopStatement();

  Loop(TokenStream tokens) {
    tokens.requireNext('Expected "for" in loop statement.', 1,
        TokenPattern(string: 'for', type: TokenType.Name));

    tokens.skip();

    // We're going to be reading ahead, so save the index so we can come back.
    tokens.saveIndex();

    // To work out if this is a for-each or just a for loop, we compare the
    //  number of tokens there are before the next 'in' to the number of
    //  tokens there are before the next braced group. If an 'in' comes
    //  before the braces, we know that this must be a for-each loop.
    var inPattern = TokenPattern(string: 'in', type: TokenType.Name);

    var untilIn = tokens.takeWhile(inPattern.notMatch);
    tokens.restoreIndex();

    var untilBraces = tokens.takeWhile(GroupPattern('{', '}').notMatch);

    // We don't restore after finding the braces, because we have all the
    //  tokens we need until then.

    var isForEach = untilIn.length < untilBraces.length;

    if (!isForEach) {
      // We may have to add a semicolon at the end because the third
      // statement doesn't require one from the user.
      if (untilBraces.isNotEmpty &&
          !TokenPattern.semicolon.hasMatch(untilBraces.last)) {
        untilBraces.add(TextToken(TokenType.Symbol, ';'));
      }

      _readClassicHeader(untilBraces);
    } else {
      // TODO: Allow multiple loop variables ("for let x, y in something").

      // Skip until 'in' because we already have the tokens up to there.
      tokens.skipWhile(inPattern.notMatch);

      // TODO: for..in (unimplemented until iterators exist).
    }

    _statement.body = Parse.statements(tokens.take().allTokens());

    // Save the index because there may not be a name.
    tokens.saveIndex();

    if (!tokens.hasCurrent()) {
      tokens.restoreIndex();
      return;
    }

    var nameToken = tokens.take();
    if (TokenPattern.type(TokenType.Name).notMatch(nameToken)) {
      tokens.restoreIndex();
      return;
    }

    if (!tokens.hasCurrent() ||
        TokenPattern.semicolon.notMatch(tokens.take())) {
      tokens.restoreIndex();
      return;
    }

    _statement.name = nameToken.toString();
  }

  /// Read the header of a classic three-part for loop.
  void _readClassicHeader(List<Token> tokens) {
    // Fallbacks in case the user omits parts.
    _statement.setup = DartStatement(() {
      return SideEffect.nothing();
    }, false);

    // Return true to keep the loop going until the user stops it.
    _statement.check = InlineExpression(() {
      return BooleanValue(true).createHandle();
    });

    // No change.
    _statement.change = InlineExpression(() {
      return null;
    });

    var headerStream = TokenStream(tokens, 0);

    if (!headerStream.hasCurrent()) {
      return;
    }

    _statement.setup = Parse.statement(headerStream);

    if (!headerStream.hasCurrent()) {
      return;
    }

    var checkTokens = headerStream.takeUntilSemicolon();
    _statement.check = Parse.expression(checkTokens);

    headerStream.consumeSemicolon(2);

    if (!headerStream.hasCurrent()) {
      return;
    }

    var changeTokens = headerStream.takeUntilSemicolon();
    _statement.change = Parse.expression(changeTokens);
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}
