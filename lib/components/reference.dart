import 'package:language/runtime/handle.dart';
import 'package:language/runtime/statements.dart';

import '../lexer.dart';
import '../parser.dart';
import '../runtime/concrete.dart';
import '../runtime/exception.dart';
import '../runtime/expression.dart';
import '../runtime/store.dart';
import '../runtime/type.dart';
import 'typename.dart';
import 'util.dart';

// TODO: Should directions be allowed in classes?
class DirectionStatement extends DynamicStatement
    implements FunctionChild, LoopChild {
  TypeName typeName;
  String name;
  Expression targetExpression;

  @override
  SideEffect execute() {
    // Evaluate the expression and then create a variable with the type.
    var evaluated = targetExpression.evaluate();

    var reference = Reference(evaluated);

    if (typeName == null) {
      var handle = Store.current().get(name);

      if (!(handle is Reference)) {
        throw RuntimeError('Cannot redirect non-reference.');
      }

      (handle as Reference).redirect(evaluated);
    } else {
      Store.current().add(name, reference);
    }

    var storedReference = Store.current().get(name) as Reference;
    var requiredType =
        typeName?.evaluate() ?? ReferenceType.to(evaluated.valueType);

    if (storedReference.handleType.notEquals(requiredType)) {
      var targetType =
          (storedReference.handleType as ReferenceType).referencedType;
      throw RuntimeError('Cannot direct "$requiredType" to "$targetType".');
    }

    storedReference.value = storedReference.convertValueTo(requiredType).value;
    // throw UnimplementedError();
    return SideEffect.nothing();
  }
}

/// The initial direction of a reference, such as:
/// ```
/// @int myReference -> someVariable;
/// ```
class Direction implements Statable {
  // TypeName _typeName;
  // String _name;
  // Expression _targetExpression;

  final _statement = DirectionStatement();

  /// Parses the part of the direction which is common between directions
  /// and redirections.
  Direction._common(TokenStream tokens) {
    tokens.requireNext(
        'Expected name in direction.', 1, TokenPattern.type(TokenType.Name));

    _statement.name = tokens.take().toString();

    tokens.requireNext('Expected "->" in direction.', 2,
        TokenPattern(string: '->', type: TokenType.Symbol));

    tokens.skip();

    var expressionTokens = tokens.takeUntilSemicolon();
    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Direction target expression may not be empty.', 3);
    }

    _statement.targetExpression = Parse.expression(expressionTokens);

    tokens.consumeSemicolon(4);
  }

  factory Direction.redirection(TokenStream tokens) {
    return Direction._common(tokens);
  }

  factory Direction(TokenStream tokens) {
    // For full directions (basically reference declarations).
    var typeName = TypeName(tokens);

    var common = Direction._common(tokens);
    common._statement.typeName = typeName;

    return common;
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}

/// Inline direction of references.
/// ```
/// someFunction(-> target);
/// ```
class InlineDirection implements Expressible {
  Expression _targetExpression;

  InlineDirection(TokenStream tokens) {
    tokens.requireNext('Token direction must begin with "->".', 1,
        TokenPattern(string: '->', type: TokenType.Symbol));

    tokens.skip();

    // The next must be a single token, so multiple tokens must be
    //  parenthesised.
    var expressionTokens = tokens.take().allTokens();
    _targetExpression = Parse.expression(expressionTokens);
  }

  @override
  Expression createExpression() {
    return InlineExpression(() => Reference(_targetExpression.evaluate()));
  }
}
