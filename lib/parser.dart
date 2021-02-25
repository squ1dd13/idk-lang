import 'package:language/components/constructor.dart';
import 'package:language/components/finally.dart';
import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/scope.dart';

import 'components/class.dart';
import 'components/class_type.dart';
import 'components/collection.dart';
import 'components/conditional.dart';
import 'components/declaration.dart';
import 'components/flow.dart';
import 'components/function.dart';
import 'components/iteration.dart';
import 'components/operations/expression.dart';
import 'components/reference.dart';
import 'components/util.dart';
import 'runtime/primitive.dart';
import 'runtime/statements.dart';

class Parse {
  static final statementPasses = <Statement Function(TokenStream)>[
    (stream) => CustomClassType(stream).createStatement(),
    (stream) => ConditionalClause(stream).createStatement(),
    (stream) => Loop(stream).createStatement(),
    (stream) => VariableDeclaration(stream).createStatement(),
    (stream) => Direction(stream).createStatement(),
    (stream) => Direction.redirection(stream).createStatement(),
    (stream) => ConstructorDeclaration(stream).createStatement(),
    (stream) => FunctionDeclaration(stream).createStatement(),
    (stream) => FlowStatement(stream).createStatement(),
    (stream) => ClassDeclaration(stream).createStatement(),
    (stream) => Finally(stream).createStatement(),
    (stream) {
      // Braces form a statement within a temporary scope.
      stream.requireNext('Expected "{}".', 1, GroupPattern('{', '}'));

      var body = Parse.statements<DynamicStatement>(stream.take().allTokens());

      // Execute the body in a new scope.
      return DartDynamicStatement(() {
        var scope = Scope(Scope.current());
        scope.enter();

        for (var statement in body) {
          var effect = statement.execute();

          // Any interrupting effects go directly through to the parent scope.
          if (effect.isInterrupt) {
            scope.leave();
            return effect;
          }
        }

        scope.leave();
        return SideEffect.nothing();
      }, false);
    },
    (stream) {
      var statement = GenericStatement(OperatorExpression(stream), false);
      stream.consumeSemicolon(3);
      return statement;
    },
  ];

  static final _expressionPasses = <Expression Function(TokenStream)>[
    (stream) => CollectionLiteral(stream).createExpression(),
    (stream) => OperatorExpression(stream),
    (stream) => InlineDirection(stream).createExpression(),
  ];

  static List<ElementType> _parseRepeated<ElementType>(TokenStream stream,
      Iterable<ElementType Function(TokenStream)> generators, int limit) {
    var created = <ElementType>[];

    while (stream.hasCurrent() && (limit < 1 || created.length < limit)) {
      // We keep the exception thrown at the furthest point in parsing so
      //  that if nothing succeeds, we know what to complain about.
      var furthestException = InvalidSyntaxException('', -1, -1, -1);

      for (var pass in generators) {
        if (!stream.hasCurrent()) {
          break;
        }

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

  static List<StatementType> statements<StatementType>(List<Token> tokens,
      {int limit = -1, List<Statement Function(TokenStream)> passes}) {
    return _parseRepeated(
            TokenStream(tokens, 0), passes ?? statementPasses, limit)
        .cast();
  }

  static Statement statement(TokenStream tokens) {
    return _parseRepeated(tokens, statementPasses, 1)[0];
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

  static bool staticKeyword(TokenStream tokens) {
    // Using 'type' instead of 'static' reinforces the idea that statics
    //  are to be associated with the type and not objects.
    const staticPattern = TokenPattern(string: 'type', type: TokenType.Name);

    var isStatic = staticPattern.hasMatch(tokens.current());

    if (isStatic) {
      // Skip 'static'.
      tokens.skip();
    }

    return isStatic;
  }

  static Expression expression(List<Token> tokens) {
    if (tokens.isEmpty) {
      throw InvalidSyntaxException('Empty', 3, -1, -1);
    }

    if (tokens.length == 1) {
      if (tokens.first.type == TokenType.String) {
        return InlineExpression(
            () => StringValue(tokens.first.toString()).createHandle());
      }

      if (tokens.first.type == TokenType.Number) {
        return InlineExpression(
            () => IntegerValue(tokens.first.toString()).createHandle());
      }

      if (tokens.first.type == TokenType.Name) {
        return InlineExpression(() {
          return Scope.current().get(tokens.first.toString());
        });
      }
    }

    var allParsed =
        _parseRepeated(TokenStream(tokens, 0), _expressionPasses, 1);

    if (allParsed.isEmpty) {
      throw RuntimeError('Unparsed!');
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
