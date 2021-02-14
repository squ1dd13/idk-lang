import '../Lexer.dart';
import '../runtime/Concepts.dart';
import '../runtime/Concrete.dart';
import '../runtime/Expression.dart';
import '../runtime/Store.dart';
import 'Function.dart';
import 'Util.dart';
import 'VariableDeclaration.dart';

class Parse {
  static final _passes = <Statement Function(TokenStream)>{
        (stream) => VariableDeclaration(stream).createStatement(),
        (stream) => FunctionDeclaration(stream).createStatement(),
  };

  static List<Statement> statements(List<Token> tokens) {
    var stream = TokenStream(tokens, 0);
    var statements = <Statement>[];

    while (stream.hasCurrent()) {
      // We keep the exception thrown at the furthest point in parsing so
      //  that if nothing succeeds, we know what to complain about.
      var furthestException = InvalidSyntaxException('', -1, -1, -1);

      for (var pass in _passes) {
        // Save the index in case this pass fails.
        stream.saveIndex();

        try {
          var parsed = pass(stream);
          statements.add(parsed);

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

    return statements;
  }

  static List<List<Token>> split(TokenStream tokens, TokenPattern pattern) {
    var segments = <List<Token>>[];

    while (tokens.hasCurrent()) {
      // Collect tokens until we find a non-match.
      var taken = tokens.takeWhile(pattern.hasMatch);

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
          return Store.current().getAs<Variable>(tokens.first.toString());
        });
      }
    }

    return InlineExpression(() {
      print('Unparsed!');
      return null;
    });
  }
}
