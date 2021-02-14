import '../Lexer.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';
import '../runtime/Store.dart';
import 'Assignment.dart';
import 'Call.dart';
import 'Function.dart';
import 'Util.dart';
import 'Declaration.dart';

class Parse {
  static final _statementPasses = <Statement Function(TokenStream)>{
    (stream) => VariableDeclaration(stream).createStatement(),
    (stream) => FunctionDeclaration(stream).createStatement(),
    (stream) {
      var statement = Statement(FunctionCall(stream).createExpression());

      // If it's a statement, there needs to be a semicolon after.
      stream.consumeSemicolon(5);

      return statement;
    },
    (stream) => Assignment(stream).createStatement(),
  };

  static final _expressionPasses = <Expression Function(TokenStream)>{
    (stream) => FunctionCall(stream).createExpression()
  };

  static List<ElementType> _parseRepeated<ElementType>(
      List<Token> tokens, Set<ElementType Function(TokenStream)> generators) {
    var stream = TokenStream(tokens, 0);
    var created = <ElementType>[];

    while (stream.hasCurrent()) {
      // We keep the exception thrown at the furthest point in parsing so
      //  that if nothing succeeds, we know what to complain about.
      var furthestException = InvalidSyntaxException('', -1, -1, -1);

      for (var pass in generators) {
        // Save the index in case this pass fails.
        stream.saveIndex();

        try {
          var parsed = pass(stream);
          created.add(parsed);

          // Invalidate the exception so it gets ignored.
          furthestException = InvalidSyntaxException('', -1, -1, -1);

          // This pass succeeded, so we can move on now.
          break;
        } on InvalidSyntaxException catch (exception) {
          // Pass failed, so restore the index so we can try again.
          stream.restoreIndex();

          if (exception.stage > furthestException.stage) {
            furthestException = exception;
          }
        }
      }

      if (furthestException.stage >= 0) {
        throw furthestException;
      }
    }

    return created;
  }

  static List<Statement> statements(List<Token> tokens) {
    return _parseRepeated(tokens, _statementPasses);
  }

  static List<List<Token>> split(TokenStream tokens, TokenPattern pattern) {
    var segments = <List<Token>>[];

    while (tokens.hasCurrent()) {
      // Collect tokens until we find a non-match.
      var taken = tokens.takeWhile(pattern.notMatch);

      if (taken.isNotEmpty) {
        segments.add(taken);
      } else {
        tokens.skip();
      }
    }

    return segments;
  }

  static Expression expression(List<Token> tokens) {
    if (tokens.length == 1) {
      if (tokens.first.type == TokenType.String) {
        return InlineExpression(() => StringValue(tokens.first.toString()));
      }

      if (tokens.first.type == TokenType.Number) {
        return InlineExpression(() => IntegerValue(tokens.first.toString()));
      }

      if (tokens.first.type == TokenType.Name) {
        return InlineExpression(() {
          return Store.current().get(tokens.first.toString());
        });
      }
    }

    var allParsed = _parseRepeated(tokens, _expressionPasses);

    if (allParsed.isEmpty) {
      return InlineExpression(() {
        print('Unparsed!');
        return null;
      });
    }

    if (allParsed.length > 1) {
      return InlineExpression(() {
        print('Too many results!');
        return null;
      });
    }

    return allParsed[0];
  }
}
